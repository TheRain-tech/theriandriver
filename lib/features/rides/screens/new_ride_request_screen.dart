import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/app_enums.dart';
import '../../../data/models/driver_trip.dart';
import '../../../data/models/ride_request.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../firebase/firestore_collections.dart';
import '../../../router/route_names.dart';
import '../../../services/auth_service.dart';
import '../../../services/commission_wallet_service.dart';
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
    if (DriverProfileService.instance.isFleetSuspended) {
      _showError(
        DriverCopy.current.t(
          'Fleet Temporarily Suspended. Ride requests are temporarily unavailable.',
          'Flotte temporairement suspendue. Les demandes de course sont temporairement indisponibles.',
        ),
      );
      return;
    }
    setState(() => _isResponding = true);
    try {
      final trip = await _repository.acceptRideRequest(
        uid: uid,
        request: request,
      );
      // Acceptance is already committed atomically by the callable above.
      // Never report that as a failed acceptance because the follow-up status
      // mirror is temporarily unavailable. The rider can safely see the
      // assigned driver and the driver can continue to pickup; the arrival
      // screen will retry its next lifecycle update when needed.
      try {
        await _repository.transitionRide(
          uid: uid,
          rideId: trip.id,
          requestId: request.requestId,
          nextStatus: RideStatuses.driverArriving,
        );
      } catch (_) {
        // The accepted ride remains valid; do not strand either participant.
      }
      TripService.instance.activeTrip.value = trip;
      TripService.instance.clearIncomingRequest();
      try {
        await LocationService.instance.setCurrentRide(trip.id);
      } catch (_) {
        // Location publishing will resume from the active-trip screen.
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, RouteNames.goToPickup);
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString();
      String friendlyMsg = DriverCopy.current.t(
        'We could not accept this ride. Please try again.',
        "Impossible d'accepter cette course. Veuillez réessayer.",
      );
      // The server refuses to let a driver take a ride when the wallet that pays for it is below the
      // minimum (a Firestore permission-denied on this exact write, or the accept function's precondition).
      // Ask the server which wallet and how much, and say so plainly instead of a generic failure.
      if (msg.contains('permission-denied') ||
          msg.contains('wallet balance is below') ||
          msg.contains('wallet balance is insufficient')) {
        final requirement = await CommissionWalletService.instance
            .fetchRequirement();
        final walletMessage = requirement?.blockMessage();
        if (walletMessage != null) {
          if (!mounted) return;
          _showError(walletMessage);
          setState(() => _isResponding = false);
          return;
        }
      }
      if (msg.contains('no longer available') ||
          msg.contains('already been assigned')) {
        friendlyMsg = DriverCopy.current.t(
          'This ride has already been assigned.',
          'Cette course a déjà été attribuée.',
        );
      } else if (msg.contains('expired')) {
        friendlyMsg = DriverCopy.current.t(
          'This request has expired.',
          'Cette demande a expiré.',
        );
      } else if (msg.contains('cancelled')) {
        friendlyMsg = DriverCopy.current.t(
          'The rider cancelled this request.',
          'Le passager a annulé cette demande.',
        );
      } else if (msg.contains('already on an active ride')) {
        friendlyMsg = DriverCopy.current.t(
          'You are already on an active ride.',
          'Vous êtes déjà en course.',
        );
      } else if (msg.contains(
        'Fleet Owner\'s wallet balance is insufficient',
      )) {
        friendlyMsg = DriverCopy.current.t(
          "Your Fleet Owner's wallet balance is insufficient. Please ask your Fleet Owner to recharge the wallet before accepting new ride requests.",
          "Le solde du portefeuille de votre propriétaire de flotte est insuffisant. Demandez à votre propriétaire de flotte de recharger le portefeuille avant d'accepter de nouvelles demandes de course.",
        );
      } else if (msg.contains('Fleet Temporarily Suspended')) {
        friendlyMsg = DriverCopy.current.t(
          'Fleet Temporarily Suspended. Ride requests are temporarily unavailable.',
          'Flotte temporairement suspendue. Les demandes de course sont temporairement indisponibles.',
        );
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
      _showError(
        DriverCopy.current.t(
          'We could not reject this request. Please try again.',
          'Impossible de refuser cette demande. Veuillez réessayer.',
        ),
      );
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
      // Contact details become actionable only after this driver accepts and
      // the assigned ride is loaded from the rides collection.
      riderPhone: '',
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

  // Stable, never-translated internal values - selectedRideType/paymentMethod are also compared
  // against raw backend strings elsewhere (e.g. _tripForRequest), so only the displayed label is
  // translated here, the same split driver_dashboard_screen.dart's _blockedReason/_blockedReasonDisplay
  // established for exactly this reason.
  String _rideTypeLabel(String rideType, DriverCopy l) {
    final normalized = rideType.trim().toLowerCase();
    return switch (normalized) {
      'classic' => l.t('Classic', 'Classique'),
      'comfort' => l.t('Comfort', 'Confort'),
      'premium' => l.t('Premium', 'Premium'),
      'vip' => l.t('VIP', 'VIP'),
      'xl' => l.t('XL', 'XL'),
      'delivery' => l.t('Delivery', 'Livraison'),
      'bike' || 'motorbike' || 'motorcycle' => l.t('Bike', 'Moto'),
      _ when rideType.isNotEmpty =>
        rideType[0].toUpperCase() + rideType.substring(1),
      _ => rideType,
    };
  }

  String _paymentMethodLabel(String paymentMethod, DriverCopy l) {
    return switch (paymentMethod.trim().toLowerCase()) {
      'cash' => l.t('Cash', 'Espèces'),
      'mobile_money' => l.t('Mobile Money', 'Mobile Money'),
      _ => paymentMethod,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    final request = _request;
    if (request == null) {
      return Scaffold(
        appBar: DriverAppBar(
          title: l.t('New Ride Request', 'Nouvelle demande de course'),
          showBack: true,
          showLogo: false,
        ),
        body: Center(
          child: Text(l.t('No active ride request.', 'Aucune demande de course active.')),
        ),
      );
    }
    final trip = _tripForRequest(request);
    final seconds = _secondsRemaining(request);

    return Scaffold(
      appBar: DriverAppBar(
        title: l.t('New Ride Request', 'Nouvelle demande de course'),
        showBack: true,
        showLogo: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: seconds <= 10
                  ? AppColors.dangerSoftFor(context)
                  : AppColors.primarySoftFor(context),
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
                  avatar: Icon(
                    Icons.near_me_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: Text(l.t('${request.distanceKm} km trip', '${request.distanceKm} km de course')),
                ),
              ),
              SizedBox(height: 12),
              MapPreviewCard(
                height: 290,
                pickupLat: request.pickupLocation.lat,
                pickupLng: request.pickupLocation.lng,
                destinationLat: request.destinationLocation.lat,
                destinationLng: request.destinationLocation.lng,
                routePolyline: request.routePolyline,
                driverRideType: request.selectedRideType,
              ),
              SizedBox(height: 14),
              TripRouteCard(pickup: trip.pickup, dropOff: trip.dropOff),
              SizedBox(height: 14),
              RiderCard(trip: trip),
              SizedBox(height: 14),
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        RideMetric(
                          icon: Icons.account_balance_wallet_outlined,
                          label: l.t('Estimated Fare', 'Tarif estimé'),
                          value: CurrencyFormatter.format(
                            request.estimatedFare,
                          ),
                        ),
                        RideMetric(
                          icon: Icons.payments_outlined,
                          label: l.t('Payment', 'Paiement'),
                          value: _paymentMethodLabel(request.paymentMethod, l),
                        ),
                        RideMetric(
                          icon: Icons.schedule_outlined,
                          label: l.t('Duration', 'Durée'),
                          value: l.t(
                            '${request.estimatedDurationMinutes} min',
                            '${request.estimatedDurationMinutes} min',
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 28),
                    Row(
                      children: [
                        RideMetric(
                          icon: Icons.directions_car_outlined,
                          label: l.t('Ride Type', 'Type de course'),
                          value: _rideTypeLabel(request.selectedRideType, l),
                        ),
                        RideMetric(
                          icon: Icons.route_outlined,
                          label: l.t('Distance', 'Distance'),
                          value: '${request.distanceKm} km',
                        ),
                        RideMetric(
                          icon: Icons.timer_outlined,
                          label: l.t('Expires In', 'Expire dans'),
                          value: l.t('$seconds sec', '$seconds s'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isResponding ? null : _decline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                      child: Text(l.t('Decline', 'Refuser')),
                    ),
                  ),
                  SizedBox(width: 12),
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
                          : Text(l.t('Accept', 'Accepter')),
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
