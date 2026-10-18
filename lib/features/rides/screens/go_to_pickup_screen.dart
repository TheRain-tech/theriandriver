import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/utils/address_formatter.dart';
import '../../../core/utils/google_maps_launcher.dart';
import '../../../core/utils/waze_launcher.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/models/live_location.dart';
import '../../../data/repositories/driver_trip_repository.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../firebase/firestore_collections.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_profile_service.dart';
import '../../../services/location_service.dart';
import '../../../services/trip_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/feature_templates.dart';
import '../widgets/driver_floating_trip_controls.dart';
import '../widgets/ride_common.dart';

const double _kAverageUrbanSpeedKmh = 28;

int? _etaMinutesToPickup(LiveLocation? driverLocation, DriverTrip trip) {
  if (driverLocation == null) return null;
  final distanceMeters = Geolocator.distanceBetween(
    driverLocation.lat,
    driverLocation.lng,
    trip.pickupLat,
    trip.pickupLng,
  );
  final minutes = (distanceMeters / 1000 / _kAverageUrbanSpeedKmh) * 60;
  return minutes.ceil().clamp(1, 999);
}

class GoToPickupScreen extends StatefulWidget {
  const GoToPickupScreen({super.key});

  @override
  State<GoToPickupScreen> createState() => _GoToPickupScreenState();
}

class _GoToPickupScreenState extends State<GoToPickupScreen> {
  final _repository = DriverTripRepository();
  final _rideRepository = RideRepository();
  bool _isResponding = false;
  StreamSubscription<DriverTrip?>? _rideSubscription;

  @override
  void initState() {
    super.initState();
    _startRideListener();
  }

  void _startRideListener() {
    final activeTrip = TripService.instance.activeTrip.value;
    if (activeTrip == null || activeTrip.id.isEmpty) return;
    _rideSubscription = _rideRepository.watchRide(activeTrip.id).listen((
      updatedTrip,
    ) {
      if (updatedTrip == null) return;
      if (updatedTrip.status == TripStatus.cancelled) {
        _handleCancellation();
      }
    });
  }

  void _handleCancellation() {
    if (!mounted) return;
    _rideSubscription?.cancel();
    _rideSubscription = null;
    final rideId = TripService.instance.activeTrip.value?.id;
    if (rideId != null) {
      unawaited(LocationService.instance.releaseCurrentRide(rideId));
    }
    TripService.instance.clearActiveTrip();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(DriverCopy.current.t('Trip Cancelled', 'Course annulee')),
        content: Text(
          DriverCopy.current.t(
            'The rider has cancelled this trip.',
            'Le passager a annule cette course.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                RouteNames.dashboard,
                (_) => false,
              );
            },
            child: Text(DriverCopy.current.t('OK', 'OK')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    super.dispose();
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );
  }

  Future<void> _showPickupNavigationOptions(DriverTrip trip) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final copy = DriverCopy.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  copy.t('Navigate with', 'Naviguer avec'),
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: Icon(Icons.map_outlined, color: AppColors.primary),
                title: Text(copy.t('Google Maps', 'Google Maps')),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final opened = await GoogleMapsLauncher.navigate(
                    lat: trip.pickupLat,
                    lng: trip.pickupLng,
                  );
                  if (opened) {
                    unawaited(
                      _rideRepository.recordNavigationStarted(
                        rideId: trip.id,
                        provider: 'google_maps',
                      ),
                    );
                  } else if (mounted) {
                    _showError(
                      DriverCopy.current.t(
                        'Could not open Google Maps. Please try again.',
                        "Impossible d'ouvrir Google Maps. Veuillez reessayer.",
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.map_outlined, color: AppColors.primary),
                title: Text(copy.t('Waze', 'Waze')),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final opened = await WazeLauncher.navigate(
                    lat: trip.pickupLat,
                    lng: trip.pickupLng,
                  );
                  if (opened) {
                    unawaited(
                      _rideRepository.recordNavigationStarted(
                        rideId: trip.id,
                        provider: 'waze',
                      ),
                    );
                  } else if (mounted) {
                    _showError(
                      DriverCopy.current.t(
                        'Could not open Waze. Please try again.',
                        "Impossible d'ouvrir Waze. Veuillez reessayer.",
                      ),
                    );
                  }
                },
              ),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onArrived(DriverTrip trip) async {
    if (_isResponding) return;
    final profile = DriverProfileService.instance.profile.value;
    final uid = profile.id.isNotEmpty
        ? profile.id
        : AuthService.instance.currentUserId ?? 'preview-driver';
    setState(() => _isResponding = true);
    try {
      await _rideRepository.transitionRide(
        uid: uid,
        rideId: trip.id,
        requestId: trip.requestId,
        nextStatus: RideStatuses.arrived,
      );
      TripService.instance.activeTrip.value = trip.copyWith(
        status: TripStatus.arrived,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, RouteNames.pickupConfirmed);
    } catch (error) {
      if (mounted) {
        _showError(
          DriverCopy.current.t(
            'We could not update arrival status. Please try again.',
            "Impossible de mettre a jour le statut d'arrivee. Veuillez reessayer.",
          ),
        );
        setState(() => _isResponding = false);
      }
    }
  }

  String _reasonLabel(String reason, DriverCopy copy) {
    switch (reason) {
      case "Rider didn't show up":
        return copy.t(reason, "Le passager ne s'est pas presente");
      case 'Rider requested cancellation':
        return copy.t(reason, "Le passager a demande l'annulation");
      case 'Vehicle issue / breakdown':
        return copy.t(reason, 'Probleme de vehicule / panne');
      case 'Too much traffic / delay':
        return copy.t(reason, 'Trop de circulation / retard');
      case 'Too many passengers / luggage':
        return copy.t(reason, 'Trop de passagers / bagages');
      case 'Other reason':
        return copy.t(reason, 'Autre motif');
      default:
        return reason;
    }
  }

  Future<void> _showCancelDialog(DriverTrip trip) async {
    final reasons = [
      "Rider didn't show up",
      "Rider requested cancellation",
      "Vehicle issue / breakdown",
      "Too much traffic / delay",
      "Too many passengers / luggage",
      "Other reason",
    ];
    String selectedReason = reasons.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(DriverCopy.current.t('Cancel Ride', 'Annuler la course')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DriverCopy.current.t(
                  'Are you sure you want to cancel this ride? Please select a reason:',
                  'Voulez-vous vraiment annuler cette course ? Veuillez choisir un motif :',
                ),
                style: TextStyle(height: 1.4),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                decoration: InputDecoration(
                  labelText: DriverCopy.current.t(
                    'Cancellation Reason',
                    "Motif d'annulation",
                  ),
                  border: const OutlineInputBorder(),
                ),
                items: reasons
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(_reasonLabel(r, DriverCopy.current)),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedReason = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                DriverCopy.current.t('No, Keep Ride', 'Non, garder la course'),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: Text(DriverCopy.current.t('Yes, Cancel', 'Oui, annuler')),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _cancelRide(trip, selectedReason);
    }
  }

  Future<void> _cancelRide(DriverTrip trip, String reason) async {
    if (_isResponding) return;
    final profile = DriverProfileService.instance.profile.value;
    final uid = profile.id.isNotEmpty
        ? profile.id
        : AuthService.instance.currentUserId ?? 'preview-driver';
    setState(() => _isResponding = true);
    try {
      await _rideRepository.transitionRide(
        uid: uid,
        rideId: trip.id,
        requestId: trip.requestId,
        nextStatus: RideStatuses.cancelled,
        reason: reason,
      );
      await LocationService.instance.releaseCurrentRide(trip.id);
      TripService.instance.clearActiveTrip();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.dashboard,
        (route) => false,
      );
    } catch (error) {
      if (mounted) {
        _showError(
          DriverCopy.current.t(
            'We could not cancel this ride. Please try again.',
            "Impossible d'annuler cette course. Veuillez reessayer.",
          ),
        );
        setState(() => _isResponding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: DriverAppBar(
      title: DriverCopy.of(
        context,
      ).t('Go to Pickup', 'Aller a la prise en charge'),
      showBack: true,
      showLogo: false,
    ),
    body: FutureBuilder<List<DriverTrip>>(
      future: _repository.getTrips(),
      builder: (context, snapshot) {
        final trip =
            TripService.instance.activeTrip.value ?? snapshot.data?.first;
        if (trip == null) {
          return Center(child: CircularProgressIndicator());
        }
        return SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const collapsedSheetHeight = 86.0;
              final minFraction = constraints.maxHeight <= 0
                  ? 0.12
                  : (collapsedSheetHeight / constraints.maxHeight)
                        .clamp(0.10, 0.24)
                        .toDouble();
              final initialFraction = constraints.maxHeight <= 0
                  ? 0.38
                  : (330 / constraints.maxHeight)
                        .clamp(minFraction, 0.52)
                        .toDouble();
              return Stack(
                children: [
                  Positioned.fill(
                    child: RideTrackingMap(
                      trip: trip,
                      height: constraints.maxHeight,
                      toPickup: true,
                    ),
                  ),
                  Positioned(
                    top: 18,
                    left: 18,
                    child: _PickupEtaPill(trip: trip),
                  ),
                  Positioned(
                    top: 18,
                    right: 18,
                    child: SafeArea(
                      bottom: false,
                      child: DriverFloatingTripControls(trip: trip),
                    ),
                  ),
                  DraggableScrollableSheet(
                    initialChildSize: initialFraction,
                    minChildSize: minFraction,
                    maxChildSize: 0.90,
                    snap: true,
                    snapSizes: [minFraction, initialFraction, 0.90],
                    builder: (context, controller) => _PickupActionSheet(
                      controller: controller,
                      trip: trip,
                      isResponding: _isResponding,
                      onNavigate: () =>
                          unawaited(_showPickupNavigationOptions(trip)),
                      onArrived: () => _onArrived(trip),
                      onCancel: () => _showCancelDialog(trip),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    ),
  );
}

class _PickupEtaPill extends StatelessWidget {
  const _PickupEtaPill({required this.trip});

  final DriverTrip trip;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ValueListenableBuilder<LiveLocation?>(
        valueListenable: LocationService.instance.currentLocation,
        builder: (context, driverLocation, _) {
          final eta = _etaMinutesToPickup(driverLocation, trip);
          return Text.rich(
            TextSpan(
              text: 'ETA ',
              children: [
                TextSpan(
                  text: eta == null ? '--' : '$eta min',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PickupActionSheet extends StatelessWidget {
  const _PickupActionSheet({
    required this.controller,
    required this.trip,
    required this.isResponding,
    required this.onNavigate,
    required this.onArrived,
    required this.onCancel,
  });

  final ScrollController controller;
  final DriverTrip trip;
  final bool isResponding;
  final VoidCallback onNavigate;
  final VoidCallback onArrived;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundFor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.borderFor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                IconWell(icon: Icons.navigation_rounded, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.t('Heading to pickup', 'En route vers le passager'),
                        style: TextStyle(
                          color: AppColors.textPrimaryFor(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        copy.t(
                          'Use Google Maps or Waze for turn-by-turn guidance.',
                          'Utilisez Google Maps ou Waze pour le guidage pas a pas.',
                        ),
                        style: TextStyle(
                          color: AppColors.textSecondaryFor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Call/Chat are floating controls over the map now (DriverFloatingTripControls),
            // not inline here - they stayed reachable even when this sheet was scrolled before,
            // but floating keeps them visible without needing the sheet open at all.
            RiderCard(trip: trip),
            if (trip.isGroupRide && trip.passengers.isNotEmpty) ...[
              const SizedBox(height: 14),
              PassengerListCard(passengers: trip.passengers),
            ],
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconWell(icon: Icons.location_on_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              copy.t(
                                'Pickup Location',
                                'Lieu de prise en charge',
                              ),
                            ),
                            Text(
                              AddressFormatter.clean(trip.pickup),
                              style: TextStyle(
                                color: AppColors.textPrimaryFor(context),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${trip.distanceKm} km',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (trip.note != null && trip.note!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoftFor(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${copy.t('Note from rider', 'Note du passager')}\n${trip.note}',
                        style: TextStyle(height: 1.45),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: trip.id.isEmpty ? null : onNavigate,
              icon: Icon(Icons.navigation_rounded),
              label: Text(
                copy.t(
                  'Open Google Maps or Waze',
                  'Ouvrir Google Maps ou Waze',
                ),
              ),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: copy.t("I've Arrived", 'Je suis arrive'),
              icon: Icons.verified_user_outlined,
              isLoading: isResponding,
              onPressed: isResponding ? null : onArrived,
            ),
            TextButton(
              onPressed: isResponding ? null : onCancel,
              child: Text(copy.t('Cancel Ride', 'Annuler la course')),
            ),
          ],
        ),
      ),
    );
  }
}
