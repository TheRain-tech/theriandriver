import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
import '../../../theme/app_colors.dart';
import 'street_pickup_share.dart';

/// Street Pickup form: pickup is the driver's own position, the destination is resolved through
/// node-api's geocoder, and the fare is node-api's own estimate. Pops with the started
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
  List<RideLocation> _suggestions = const [];
  bool _searching = false;
  Timer? _searchDebounce;
  int _searchGeneration = 0;
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
    _locatePickup();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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

  void _onDestinationChanged(String value) {
    _searchDebounce?.cancel();
    if (_destination != null) {
      setState(() {
        _destination = null;
        _quote = null;
      });
    }
    if (value.trim().length < 3) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _search(value),
    );
  }

  Future<void> _search(String query) async {
    final generation = ++_searchGeneration;
    setState(() => _searching = true);
    List<RideLocation> results;
    try {
      results = await _repository.searchDestination(query);
    } catch (_) {
      results = const [];
    }
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _suggestions = results;
      _searching = false;
    });
  }

  void _selectDestination(RideLocation destination) {
    FocusScope.of(context).unfocus();
    _searchDebounce?.cancel();
    _searchGeneration++;
    _destinationController.text = destination.address;
    setState(() {
      _destination = destination;
      _suggestions = const [];
      _searching = false;
    });
    _refreshQuote();
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
              _label(l.t('Destination', 'Destination')),
              TextField(
                controller: _destinationController,
                textInputAction: TextInputAction.search,
                onChanged: _onDestinationChanged,
                onSubmitted: (value) {
                  if (_destination == null && value.trim().length >= 3) {
                    _search(value);
                  }
                },
                decoration: _fieldDecoration(
                  hint: l.t(
                    'Enter destination...',
                    'Saisissez la destination...',
                  ),
                  prefixIcon: const Icon(
                    Icons.location_on,
                    color: AppColors.danger,
                  ),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _destination != null
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                        )
                      : null,
                ),
              ),
              if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurfaceFor(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderFor(context)),
                  ),
                  child: Column(
                    children: [
                      for (final suggestion in _suggestions)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            suggestion.address,
                            style: TextStyle(
                              color: AppColors.textPrimaryFor(context),
                            ),
                          ),
                          onTap: () => _selectDestination(suggestion),
                        ),
                    ],
                  ),
                )
              else if (!_searching &&
                  _destination == null &&
                  _destinationController.text.trim().length >= 3 &&
                  _searchDebounce?.isActive != true)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l.t(
                      'No matching place found. Try adding the neighbourhood or city.',
                      'Aucun lieu correspondant. Essayez d\'ajouter le quartier ou la ville.',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryFor(context),
                    ),
                  ),
                ),
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
