import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/models/ride_request.dart';
import '../../../data/models/street_pickup_quote.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../data/repositories/street_pickup_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_profile_service.dart';
import '../../../services/location_service.dart';
import '../../../services/places_service.dart';
import '../../../theme/app_colors.dart';
import 'street_pickup_destination_map_screen.dart';
import 'street_pickup_share.dart';

/// Street Pickup form: pickup is the driver's own position, the destination comes from the
/// rider app's own Places search (or a map pin), and the fare is node-api's own estimate. Pops with the started
/// [DriverTrip] once the ride exists and is in progress, or null if the driver backs out.
class StreetPickupSheet extends StatefulWidget {
  const StreetPickupSheet({super.key, required this.copy});

  /// Resolved from the screen that opened the sheet - see road_alert_button.dart's
  /// _RoadAlertActionSheet for why a bottom sheet's own context can't be trusted for this.
  final DriverCopy copy;

  static Future<DriverTrip?> show(BuildContext context) {
    final copy = DriverCopy.of(context);
    return showModalBottomSheet<DriverTrip>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceFor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StreetPickupSheet(copy: copy),
    );
  }

  @override
  State<StreetPickupSheet> createState() => _StreetPickupSheetState();
}

class _StreetPickupSheetState extends State<StreetPickupSheet> {
  final _repository = StreetPickupRepository();
  final _destinationController = TextEditingController();
  final _phoneController = TextEditingController();

  RideLocation? _pickup;
  bool _locatingPickup = true;
  RideLocation? _destination;
  final _destinationFocusNode = FocusNode();
  // One Places session per sheet, as the rider app does per search screen.
  final _sessionToken = const Uuid().v4();
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _searchFailed = false;
  bool _resolvingDestination = false;
  Timer? _searchDebounce;
  String _rideType = StreetPickupRepository.rideTypes.first;
  StreetPickupQuote? _quote;
  bool _quoting = false;
  bool _quoteFailed = false;
  int _quoteGeneration = 0;
  bool _starting = false;

  DriverCopy get l => widget.copy;

  @override
  void initState() {
    super.initState();
    _destinationFocusNode.addListener(_onDestinationFocusChanged);
    _locatePickup();
  }

  void _onDestinationFocusChanged() => setState(() {});

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _destinationFocusNode.removeListener(_onDestinationFocusChanged);
    _destinationFocusNode.dispose();
    _destinationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _locatePickup() async {
    double? lat;
    double? lng;
    final live = LocationService.instance.currentLocation.value;
    if (live != null) {
      lat = live.lat;
      lng = live.lng;
    } else {
      try {
        final position = await Geolocator.getCurrentPosition();
        lat = position.latitude;
        lng = position.longitude;
      } catch (_) {}
    }
    if (lat == null || lng == null) {
      if (mounted) setState(() => _locatingPickup = false);
      return;
    }
    final address = await _repository.addressFor(lat, lng);
    if (!mounted) return;
    setState(() {
      _pickup = RideLocation(
        lat: lat!,
        lng: lng!,
        address: address ?? l.t('Current location', 'Position actuelle'),
      );
      _locatingPickup = false;
    });
    _refreshQuote();
  }

  // Same debounce/search flow as the rider app's DestinationSearchScreen#_onQueryChanged.
  void _onDestinationChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();
    setState(() {
      if (_destination != null) {
        _destination = null;
        _quote = null;
        _quoteFailed = false;
      }
      _suggestions = const [];
      _searchFailed = false;
      _searching = trimmed.length >= 2;
    });
    if (trimmed.length < 2) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(trimmed),
    );
  }

  Future<void> _search(String query) async {
    final near = _pickup;
    try {
      final results = await _repository.searchDestination(
        query: query,
        sessionToken: _sessionToken,
        latitude: near?.lat,
        longitude: near?.lng,
      );
      if (!mounted || _destinationController.text.trim() != query) return;
      setState(() {
        _suggestions = results;
        _searchFailed = false;
      });
    } catch (_) {
      if (!mounted || _destinationController.text.trim() != query) return;
      setState(() {
        _suggestions = const [];
        _searchFailed = true;
      });
    } finally {
      if (mounted && _destinationController.text.trim() == query) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    _searchDebounce?.cancel();
    setState(() {
      _destinationController.text = suggestion.displayText;
      _suggestions = const [];
      _searching = false;
      _resolvingDestination = true;
    });
    try {
      final destination = await _repository.resolveDestination(
        suggestion: suggestion,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      _setDestination(destination);
    } catch (_) {
      if (!mounted) return;
      setState(() => _resolvingDestination = false);
      _showError(
        l.t(
          'Could not find that place on the map. Try another result or choose on map.',
          'Impossible de localiser ce lieu. Essayez un autre résultat ou choisissez sur la carte.',
        ),
      );
    }
  }

  void _setDestination(RideLocation destination) {
    _destinationController.text = destination.address;
    setState(() {
      _destination = destination;
      _suggestions = const [];
      _searching = false;
      _searchFailed = false;
      _resolvingDestination = false;
    });
    _refreshQuote();
  }

  Future<void> _chooseDestinationOnMap() async {
    FocusScope.of(context).unfocus();
    _searchDebounce?.cancel();
    final destination = await Navigator.of(context).push<RideLocation>(
      MaterialPageRoute(
        builder: (_) => StreetPickupDestinationMapScreen(
          copy: l,
          initialLat: _destination?.lat ?? _pickup?.lat,
          initialLng: _destination?.lng ?? _pickup?.lng,
        ),
      ),
    );
    if (destination == null || !mounted) return;
    _setDestination(destination);
  }

  void _selectRideType(String rideType) {
    if (rideType == _rideType) return;
    setState(() => _rideType = rideType);
    _refreshQuote();
  }

  Future<void> _refreshQuote() async {
    final pickup = _pickup;
    final destination = _destination;
    if (pickup == null || destination == null) return;
    final generation = ++_quoteGeneration;
    setState(() {
      _quoting = true;
      _quoteFailed = false;
      _quote = null;
    });
    StreetPickupQuote? quote;
    try {
      quote = await _repository.quote(
        pickup: pickup,
        destination: destination,
        rideType: _rideType,
        regionId: DriverProfileService.instance.profile.value.regionId,
      );
    } catch (_) {
      quote = null;
    }
    if (!mounted || generation != _quoteGeneration) return;
    setState(() {
      _quote = quote;
      _quoteFailed = quote == null;
      _quoting = false;
    });
  }

  Future<void> _start() async {
    final pickup = _pickup;
    final destination = _destination;
    final quote = _quote;
    if (pickup == null || destination == null || quote == null || _starting) {
      return;
    }
    final profile = DriverProfileService.instance.profile.value;
    final uid = profile.id.isNotEmpty
        ? profile.id
        : AuthService.instance.currentUserId;
    if (uid == null) return;
    setState(() => _starting = true);
    try {
      final trip = await RideRepository().createStreetPickupRide(
        uid: uid,
        pickup: pickup,
        destination: destination,
        rideType: _rideType,
        quote: quote,
        passengerPhone: _phoneController.text,
      );
      if (mounted) Navigator.pop(context, trip);
    } catch (error) {
      if (!mounted) return;
      setState(() => _starting = false);
      final message = error.toString();
      _showError(
        message.contains('already on an active ride')
            ? l.t(
                'You are already on an active ride.',
                'Vous êtes déjà en course.',
              )
            : message.contains('permission-denied')
            ? l.t(
                'Your wallet balance is too low to start a ride. Please top up and try again.',
                'Le solde de votre portefeuille est insuffisant pour démarrer une course. Veuillez le recharger et réessayer.',
              )
            : l.t(
                'We could not start this trip. Please try again.',
                'Impossible de démarrer cette course. Veuillez réessayer.',
              ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  // Results under the destination field, laid out like the rider app's
  // DestinationSearchScreen#_buildSearchResults: progress bar while searching, placeholder rows
  // until the first results arrive, result cards, a "not found" state offering the map, and an
  // inline warning when the search itself failed.
  List<Widget> _destinationResults() {
    final hasQuery = _destinationController.text.trim().length >= 2;
    if (_destination != null || _resolvingDestination || !hasQuery) {
      return const [];
    }
    return [
      if (_searching) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.primarySoftFor(context),
        ),
      ],
      if (_searchFailed) ...[
        const SizedBox(height: 12),
        _InlineSearchError(
          message: l.t(
            'We could not search places right now. Check your connection or choose on map.',
            'Impossible de rechercher des lieux pour le moment. Vérifiez votre connexion ou choisissez sur la carte.',
          ),
        ),
      ],
      if (_suggestions.isEmpty && _searching) ...[
        const SizedBox(height: 12),
        const _SearchResultSkeleton(),
        const SizedBox(height: 8),
        const _SearchResultSkeleton(),
      ] else if (_suggestions.isEmpty && !_searchFailed && !_searching) ...[
        const SizedBox(height: 12),
        _DestinationNotFound(copy: l, onChooseOnMap: _chooseDestinationOnMap),
      ] else if (_suggestions.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          l.t('Search results', 'Résultats de recherche'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryFor(context),
          ),
        ),
        const SizedBox(height: 8),
        for (final suggestion in _suggestions) ...[
          _PlaceResultTile(
            suggestion: suggestion,
            onTap: () => _selectSuggestion(suggestion),
          ),
          const SizedBox(height: 8),
        ],
      ],
    ];
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: border(AppColors.borderFor(context)),
      enabledBorder: border(AppColors.borderFor(context)),
      focusedBorder: border(AppColors.primary),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: AppColors.textPrimaryFor(context),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderFor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.t('🚖 Street Pickup', '🚖 Prise en charge dans la rue'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryFor(context),
                ),
              ),
              Text(
                l.t(
                  'Enter passenger details to start trip',
                  'Saisissez les détails du passager pour démarrer la course',
                ),
                style: TextStyle(
                  color: AppColors.textSecondaryFor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              _label(l.t('Pickup Location', 'Lieu de prise en charge')),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.my_location,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locatingPickup
                            ? l.t(
                                'Detecting your location...',
                                'Détection de votre position...',
                              )
                            : _pickup?.address ??
                                  l.t(
                                    'Location unavailable - turn on location to continue',
                                    'Position indisponible - activez la localisation pour continuer',
                                  ),
                        style: TextStyle(
                          fontSize: 13,
                          color: _pickup == null && !_locatingPickup
                              ? AppColors.danger
                              : AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _DestinationField(
                controller: _destinationController,
                focusNode: _destinationFocusNode,
                label: l.t('Destination', 'Destination'),
                hint: l.t('Search destination', 'Rechercher une destination'),
                isActive: _destinationFocusNode.hasFocus,
                isResolving: _resolvingDestination,
                isSet: _destination != null,
                onChanged: _onDestinationChanged,
                onTapMap: _chooseDestinationOnMap,
              ),
              ..._destinationResults(),
              const SizedBox(height: 16),
              _label(
                l.t(
                  'Passenger Phone (optional)',
                  'Téléphone du passager (facultatif)',
                ),
              ),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _fieldDecoration(
                  hint: '+237 6XX XXX XXX',
                  prefixIcon: const Icon(Icons.phone, color: AppColors.success),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.t(
                    'Used to share the trip details with the passenger.',
                    'Utilisé pour partager les détails de la course avec le passager.',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryFor(context),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _label(l.t('Ride Type', 'Type de course')),
              Row(
                children: [
                  for (final type in StreetPickupRepository.rideTypes)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: type == StreetPickupRepository.rideTypes.last
                              ? 0
                              : 8,
                        ),
                        child: _RideTypeChip(
                          label: StreetPickupShare.rideTypeLabel(type, l),
                          selected: _rideType == type,
                          onTap: () => _selectRideType(type),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _FareSummary(
                copy: l,
                quote: _quote,
                loading: _quoting,
                failed: _quoteFailed,
                onRetry: _refreshQuote,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: l.t('🚖 Start Street Pickup', '🚖 Démarrer la course'),
                isLoading: _starting,
                onPressed: _pickup == null || _quote == null || _starting
                    ? null
                    : _start,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The rider app's destination field (DestinationSearchScreen's _LocationTextField): a genuinely
// editable field with the label inside it, highlighted while active, and a trailing Map button
// for drivers who would rather drop a pin than type.
class _DestinationField extends StatelessWidget {
  const _DestinationField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.isActive,
    required this.isResolving,
    required this.isSet,
    required this.onChanged,
    required this.onTapMap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final bool isActive;
  final bool isResolving;
  final bool isSet;
  final ValueChanged<String> onChanged;
  final VoidCallback onTapMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primarySoftFor(context)
            : AppColors.elevatedSurfaceFor(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.borderFor(context),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryFor(context),
                  ),
                ),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  maxLines: 1,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryFor(context),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: hint,
                  ),
                ),
              ],
            ),
          ),
          if (isResolving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (isSet)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.check_circle_rounded, color: AppColors.success),
            ),
          IconButton(
            onPressed: onTapMap,
            icon: const Icon(Icons.map_outlined),
            color: AppColors.primary,
            tooltip: 'Map',
          ),
        ],
      ),
    );
  }
}

// The rider app's LocationResultTile: round icon, place name, secondary area line, chevron.
class _PlaceResultTile extends StatelessWidget {
  const _PlaceResultTile({required this.suggestion, required this.onTap});

  final PlaceSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceFor(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderFor(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoftFor(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.primaryText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryFor(context),
                      ),
                    ),
                    if (suggestion.secondaryText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        suggestion.secondaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryFor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondaryFor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultSkeleton extends StatelessWidget {
  const _SearchResultSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar({double? width, required double height}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.borderFor(context),
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.borderFor(context),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(width: 180, height: 15),
              const SizedBox(height: 8),
              bar(height: 11),
            ],
          ),
        ),
      ],
    );
  }
}

class _DestinationNotFound extends StatelessWidget {
  const _DestinationNotFound({required this.copy, required this.onChooseOnMap});

  final DriverCopy copy;
  final VoidCallback onChooseOnMap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.location_searching_rounded,
          size: 40,
          color: AppColors.textSecondaryFor(context),
        ),
        const SizedBox(height: 8),
        Text(
          copy.t('Destination not found', 'Destination introuvable'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryFor(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          copy.t(
            'Try a nearby landmark or neighbourhood, or choose it on the map.',
            'Essayez un repère ou un quartier proche, ou choisissez sur la carte.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryFor(context),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onChooseOnMap,
          icon: const Icon(Icons.map_outlined),
          label: Text(copy.t('Choose on map', 'Choisir sur la carte')),
        ),
      ],
    );
  }
}

class _InlineSearchError extends StatelessWidget {
  const _InlineSearchError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningSoftFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningYellow),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimaryFor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RideTypeChip extends StatelessWidget {
  const _RideTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary
          : AppColors.elevatedSurfaceFor(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.borderFor(context),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : AppColors.textPrimaryFor(context),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _FareSummary extends StatelessWidget {
  const _FareSummary({
    required this.copy,
    required this.quote,
    required this.loading,
    required this.failed,
    required this.onRetry,
  });

  final DriverCopy copy;
  final StreetPickupQuote? quote;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = copy;
    final Widget content;
    if (loading) {
      content = Row(
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(l.t('Estimating fare...', 'Estimation du tarif...')),
        ],
      );
    } else if (failed) {
      content = Row(
        children: [
          Expanded(
            child: Text(
              l.t(
                'Could not estimate the fare.',
                "Impossible d'estimer le tarif.",
              ),
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(l.t('Retry', 'Réessayer')),
          ),
        ],
      );
    } else if (quote != null) {
      final q = quote!;
      content = Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('Estimated fare (cash)', 'Tarif estimé (espèces)'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryFor(context),
                  ),
                ),
                Text(
                  CurrencyFormatter.format(q.fare),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryFor(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${q.distanceKm} km • ${q.durationMinutes} min',
            style: TextStyle(color: AppColors.textSecondaryFor(context)),
          ),
        ],
      );
    } else {
      content = Text(
        l.t(
          'Choose a destination to see the fare.',
          'Choisissez une destination pour voir le tarif.',
        ),
        style: TextStyle(color: AppColors.textSecondaryFor(context)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoftFor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: content,
    );
  }
}
