import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/widgets/outline_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/repositories/driver_trip_repository.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../firebase/firestore_collections.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_profile_service.dart';
import '../../../services/trip_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/feature_templates.dart';
import '../widgets/ride_common.dart';

class PickupConfirmedScreen extends StatefulWidget {
  const PickupConfirmedScreen({super.key});

  @override
  State<PickupConfirmedScreen> createState() => _PickupConfirmedScreenState();
}

class _PickupConfirmedScreenState extends State<PickupConfirmedScreen> {
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

  Future<void> _startTrip(DriverTrip trip) async {
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
        nextStatus: RideStatuses.ongoing,
      );
      TripService.instance.activeTrip.value = trip.copyWith(
        status: TripStatus.inProgress,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, RouteNames.tripInProgress);
    } catch (error) {
      if (mounted) {
        _showError('We could not start the trip. Please try again.');
        setState(() => _isResponding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const DriverAppBar(showOnline: true),
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
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 40,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pickup Confirmed',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    StatusBadge(label: 'Arrived'),
                  ],
                ),
                const SizedBox(height: 5),
                const Text("You've arrived at the pickup location."),
                const SizedBox(height: 18),
                RideTrackingMap(trip: trip, height: 210, toPickup: true),
                const SizedBox(height: 14),
                RiderCard(trip: trip),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    children: [
                      LabeledValue(
                        icon: Icons.lock_outline_rounded,
                        label: 'Pickup Verification Code',
                        value: trip.pickupCode.isNotEmpty
                            ? trip.pickupCode
                            : 'Confirm rider identity',
                        valueColor: AppColors.primary,
                      ),
                      if (trip.note != null && trip.note!.isNotEmpty) ...[
                        const Divider(height: 28),
                        LabeledValue(
                          icon: Icons.luggage_outlined,
                          label: 'Rider Note',
                          value: trip.note!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Start Trip',
                  icon: Icons.play_arrow_rounded,
                  isLoading: _isResponding,
                  onPressed: _isResponding ? null : () => _startTrip(trip),
                ),
                const SizedBox(height: 12),
                AppOutlineButton(
                  label: 'Message Rider',
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () {},
                ),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, RouteNames.reportIssue),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Report an issue'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
