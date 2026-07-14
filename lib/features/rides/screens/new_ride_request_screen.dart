import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/models/ride_request.dart';
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
import '../../shared/widgets/map_preview_card.dart';
import '../../shared/widgets/trip_route_card.dart';
import '../widgets/ride_common.dart';

class NewRideRequestScreen extends StatefulWidget {
  const NewRideRequestScreen({super.key});

  @override
  State<NewRideRequestScreen> createState() => _NewRideRequestScreenState();
}

class _NewRideRequestScreenState extends State<NewRideRequestScreen> {
  final _repository = RideRepository();
  StreamSubscription<RideRequest?>? _requestSubscription;
  Timer? _countdownTimer;
  RideRequest? _request;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _request = TripService.instance.incomingRequest.value;
    final profile = DriverProfileService.instance.profile.value;
    final uid = profile.id.isNotEmpty
        ? profile.id
        : AuthService.instance.currentUserId ?? 'preview-driver';
    _requestSubscription = _repository.watchIncomingRequest(uid).listen((
      request,
    ) {
      if (!mounted || _isResponding) return;
      setState(() => _request = request);
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _accept() async {
    final request = _request;
    final profile = DriverProfileService.instance.profile.value;
    final uid = profile.id.isNotEmpty
        ? profile.id
        : AuthService.instance.currentUserId ?? 'preview-driver';
    if (request == null || _isResponding) return;
    setState(() => _isResponding = true);
    try {
      final trip = await _repository.acceptRideRequest(
        uid: uid,
        request: request,
      );
      await _repository.transitionRide(
        uid: uid,
        rideId: trip.id,
        requestId: request.requestId,
        nextStatus: RideStatuses.driverArriving,
      );
      TripService.instance.activeTrip.value = trip;
      TripService.instance.clearIncomingRequest();
      await LocationService.instance.setCurrentRide(trip.id);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, RouteNames.goToPickup);
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString();
      String friendlyMsg = 'We could not accept this ride. Please try again.';
      if (msg.contains('no longer available') ||
          msg.contains('already been assigned')) {
        friendlyMsg = 'This ride has already been assigned.';
      } else if (msg.contains('expired')) {
        friendlyMsg = 'This request has expired.';
      } else if (msg.contains('cancelled')) {
        friendlyMsg = 'The rider cancelled this request.';
      } else if (msg.contains('already on an active ride')) {
        friendlyMsg = 'You are already on an active ride.';
      } else if (msg.contains('Fleet Owner\'s wallet balance is insufficient')) {
        friendlyMsg =
            "Your Fleet Owner's wallet balance is insufficient. Please ask your Fleet Owner to recharge the wallet before accepting new ride requests.";
      }
      _showError(friendlyMsg);
      setState(() => _isResponding = false);
    }
  }

  Future<void> _decline() async {
    final request = _request;
    final profile = DriverProfileService.instance.profile.value;
    final uid = profile.id.isNotEmpty
        ? profile.id
        : AuthService.instance.currentUserId ?? 'preview-driver';
    if (request == null || _isResponding) return;
    setState(() => _isResponding = true);
    try {
      await _repository.declineRideRequest(
        uid: uid,
        requestId: request.requestId,
      );
      TripService.instance.clearIncomingRequest();
      if (!mounted) return;
      Navigator.maybePop(context);
    } catch (error) {
      if (!mounted) return;
      _showError('We could not reject this request. Please try again.');
      setState(() => _isResponding = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );
  }

  int _secondsRemaining(RideRequest request) {
    final expiresAt = request.expiresAt;
    if (expiresAt == null) return 0;
    return expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 999);
  }

  DriverTrip _tripForRequest(RideRequest request) {
    return DriverTrip(
      id: request.assignedRideId ?? '',
      driverId: request.assignedDriverId ?? '',
      riderName: request.riderName,
      riderRating: 0,
      pickup: request.pickupLocation.address,
      dropOff: request.destinationLocation.address,
      fare: request.estimatedFare,
      paymentMethod: request.paymentMethod == 'mobile_money'
          ? PaymentMethod.mobileMoney
          : PaymentMethod.cash,
      paymentStatus: PaymentStatus.pending,
      status: TripStatus.requested,
      rideType: request.selectedRideType,
      distanceKm: request.distanceKm,
      durationMinutes: request.estimatedDurationMinutes,
      createdAt: request.createdAt ?? DateTime.now(),
      requestId: request.requestId,
      riderId: request.riderId,
      riderPhone: request.riderPhone,
      pickupLat: request.pickupLocation.lat,
      pickupLng: request.pickupLocation.lng,
      dropOffLat: request.destinationLocation.lat,
      dropOffLng: request.destinationLocation.lng,
      routePolyline: request.routePolyline,
    );
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    if (request == null) {
      return Scaffold(
        appBar: const DriverAppBar(
          title: 'New Ride Request',
          showBack: true,
          showLogo: false,
        ),
        body: const Center(child: Text('No active ride request.')),
      );
    }
    final trip = _tripForRequest(request);
    final seconds = _secondsRemaining(request);

    return Scaffold(
      appBar: DriverAppBar(
        title: 'New Ride Request',
        showBack: true,
        showLogo: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: seconds <= 10
                  ? AppColors.dangerSoft
                  : AppColors.primarySoft,
              child: Text(
                '$seconds',
                style: TextStyle(
                  color: seconds <= 10 ? AppColors.danger : AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Chip(
                  avatar: const Icon(
                    Icons.near_me_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: Text('${request.distanceKm} km trip'),
                ),
              ),
              const SizedBox(height: 12),
              MapPreviewCard(
                height: 290,
                pickupLat: request.pickupLocation.lat,
                pickupLng: request.pickupLocation.lng,
                destinationLat: request.destinationLocation.lat,
                destinationLng: request.destinationLocation.lng,
                routePolyline: request.routePolyline,
              ),
              const SizedBox(height: 14),
              TripRouteCard(pickup: trip.pickup, dropOff: trip.dropOff),
              const SizedBox(height: 14),
              RiderCard(trip: trip),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        RideMetric(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Estimated Fare',
                          value: CurrencyFormatter.format(
                            request.estimatedFare,
                          ),
                        ),
                        RideMetric(
                          icon: Icons.payments_outlined,
                          label: 'Payment',
                          value: request.paymentMethod,
                        ),
                        RideMetric(
                          icon: Icons.schedule_outlined,
                          label: 'Duration',
                          value: '${request.estimatedDurationMinutes} min',
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      children: [
                        RideMetric(
                          icon: Icons.directions_car_outlined,
                          label: 'Ride Type',
                          value: request.selectedRideType,
                        ),
                        RideMetric(
                          icon: Icons.route_outlined,
                          label: 'Distance',
                          value: '${request.distanceKm} km',
                        ),
                        RideMetric(
                          icon: Icons.timer_outlined,
                          label: 'Expires In',
                          value: '$seconds sec',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isResponding ? null : _decline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isResponding || seconds == 0 ? null : _accept,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                      child: _isResponding
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
