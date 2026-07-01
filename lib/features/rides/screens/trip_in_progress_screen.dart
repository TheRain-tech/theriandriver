import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/danger_button.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/repositories/driver_trip_repository.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/location_service.dart';
import '../../../services/trip_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/driver_bottom_nav.dart';
import '../../shared/widgets/feature_templates.dart';
import '../../shared/widgets/trip_route_card.dart';
import '../widgets/ride_common.dart';

class TripInProgressScreen extends StatefulWidget {
  const TripInProgressScreen({super.key});

  @override
  State<TripInProgressScreen> createState() => _TripInProgressScreenState();
}

class _TripInProgressScreenState extends State<TripInProgressScreen> {
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
    TripService.instance.clearActiveTrip();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Trip Cancelled'),
        content: const Text('The rider has cancelled this trip.'),
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
            child: const Text('OK'),
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

  Future<void> _confirmEndTrip(DriverTrip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Trip'),
        content: const Text('Are you sure you want to complete this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Yes, Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _endTrip(trip);
    }
  }

  Future<void> _endTrip(DriverTrip trip) async {
    if (_isResponding) return;
    final uid = AuthService.instance.currentUserId ?? 'preview-driver';
    setState(() => _isResponding = true);
    try {
      await _rideRepository.completeRide(uid: uid, trip: trip);
      TripService.instance.clearActiveTrip();
      await LocationService.instance.setCurrentRide(null);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        RouteNames.tripCompleted,
        arguments: trip,
      );
    } catch (error) {
      if (mounted) {
        _showError('We could not complete the trip. Please try again.');
        setState(() => _isResponding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: DriverAppBar(
      showOnline: true,
      actions: [
        IconButton(
          onPressed: () => Navigator.pushNamed(context, RouteNames.emergency),
          icon: const Icon(
            Icons.sos_rounded,
            color: AppColors.danger,
            size: 30,
          ),
        ),
      ],
    ),
    body: FutureBuilder<List<DriverTrip>>(
      future: _repository.getTrips(),
      builder: (context, snapshot) {
        final trip =
            TripService.instance.activeTrip.value ?? snapshot.data?.first;
        if (trip == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Trip in Progress',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                const Text('• Navigating to destination'),
                const SizedBox(height: 14),
                RideTrackingMap(trip: trip, height: 310, toPickup: false),
                const SizedBox(height: 14),
                TripRouteCard(
                  pickup: trip.pickup,
                  dropOff: trip.dropOff,
                  dropOffLabel: 'Destination',
                ),
                const SizedBox(height: 14),
                RiderCard(trip: trip, showChat: true),
                const SizedBox(height: 14),
                AppCard(
                  child: Row(
                    children: [
                      RideMetric(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Earnings',
                        value: CurrencyFormatter.format(trip.fare),
                      ),
                      RideMetric(
                        icon: Icons.schedule_outlined,
                        label: 'Trip Time',
                        value: '${trip.durationMinutes} min',
                      ),
                      RideMetric(
                        icon: Icons.location_on_outlined,
                        label: 'Distance',
                        value: '${trip.distanceKm} km',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                DangerButton(
                  label: 'End Trip',
                  isLoading: _isResponding,
                  onPressed: _isResponding ? null : () => _confirmEndTrip(trip),
                ),
              ],
            ),
          ),
        );
      },
    ),
    bottomNavigationBar: const DriverBottomNav(currentIndex: 2),
  );
}
