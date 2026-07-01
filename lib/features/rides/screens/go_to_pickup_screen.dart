import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/repositories/driver_trip_repository.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../firebase/firestore_collections.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/trip_service.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/driver_app_bar.dart';
import '../../shared/widgets/feature_templates.dart';
import '../widgets/ride_common.dart';

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

  Future<void> _onArrived(DriverTrip trip) async {
    if (_isResponding) return;
    final uid = AuthService.instance.currentUserId ?? 'preview-driver';
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
        _showError('We could not update arrival status. Please try again.');
        setState(() => _isResponding = false);
      }
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
          title: const Text('Cancel Ride'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to cancel this ride? Please select a reason:',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                decoration: const InputDecoration(
                  labelText: 'Cancellation Reason',
                  border: OutlineInputBorder(),
                ),
                items: reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
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
              child: const Text('No, Keep Ride'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Yes, Cancel'),
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
    final uid = AuthService.instance.currentUserId ?? 'preview-driver';
    setState(() => _isResponding = true);
    try {
      await _rideRepository.transitionRide(
        uid: uid,
        rideId: trip.id,
        requestId: trip.requestId,
        nextStatus: RideStatuses.cancelled,
        reason: reason,
      );
      TripService.instance.clearActiveTrip();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.dashboard,
        (route) => false,
      );
    } catch (error) {
      if (mounted) {
        _showError('We could not cancel this ride. Please try again.');
        setState(() => _isResponding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const DriverAppBar(
      title: 'Go to Pickup',
      showBack: true,
      showLogo: false,
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
            child: Column(
              children: [
                Stack(
                  children: [
                    RideTrackingMap(trip: trip, height: 410, toPickup: true),
                    Positioned(
                      top: 18,
                      left: 18,
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Text.rich(
                          const TextSpan(
                            text: 'ETA ',
                            children: [
                              TextSpan(
                                text: '4 min',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RiderCard(trip: trip, showChat: true),
                      const SizedBox(height: 14),
                      AppCard(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const IconWell(icon: Icons.location_on_rounded),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Pickup Location'),
                                      Text(
                                        trip.pickup,
                                        style: const TextStyle(
                                          color: AppColors.navy,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const Text('Near EcoBank entrance'),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${trip.distanceKm} km',
                                  style: const TextStyle(
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
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  'Note from rider\n${trip.note}',
                                  style: const TextStyle(height: 1.45),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      PrimaryButton(
                        label: "I've Arrived",
                        icon: Icons.verified_user_outlined,
                        isLoading: _isResponding,
                        onPressed: _isResponding
                            ? null
                            : () => _onArrived(trip),
                      ),
                      TextButton(
                        onPressed: _isResponding
                            ? null
                            : () => _showCancelDialog(trip),
                        child: const Text('Cancel Ride'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
