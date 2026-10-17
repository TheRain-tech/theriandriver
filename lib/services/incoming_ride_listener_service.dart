import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/env_config.dart';
import '../data/models/ride_request.dart';
import '../data/repositories/ride_repository.dart';
import 'auth_service.dart';
import 'driver_profile_service.dart';
import 'notification_service.dart';
import 'trip_service.dart';

/// Owns the incoming-ride-request Firestore subscription and the sound alert it triggers,
/// as an app-lifetime singleton rather than state scoped to DriverDashboardScreen.
///
/// Previously this lived entirely inside DriverDashboardScreen's State, so
/// NotificationService.instance.showIncomingRideAlert() only ever fired while the driver was on
/// the Dashboard tab - DriverBottomNav's onDestinationSelected does a
/// Navigator.pushNamedAndRemoveUntil to the other tabs, which disposes the dashboard screen (and
/// its subscription) entirely. A new ride request that arrived while the driver was on Earnings,
/// Map, Chat or Profile produced no sound at all. Started once from the app root
/// (TheRainDriverApp's State) so it survives every in-app navigation.
class IncomingRideListenerService {
  IncomingRideListenerService._();
  static final instance = IncomingRideListenerService._();

  final _rideRepository = RideRepository();
  StreamSubscription<RideRequest?>? _requestSubscription;
  String? _listeningDriverId;
  bool _started = false;

  /// Ticks (via a monotonically increasing counter, not the error itself) whenever the Firestore
  /// subscription errors, so a currently-mounted screen can show its own translated message.
  /// Optional to observe - the sound/alert mechanism itself does not depend on anyone listening.
  final ValueNotifier<int> errorTick = ValueNotifier(0);

  void start() {
    if (_started) return;
    _started = true;
    DriverProfileService.instance.profile.addListener(_sync);
    DriverProfileService.instance.fleetInfo.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (DriverProfileService.instance.isFleetSuspended) {
      unawaited(_requestSubscription?.cancel());
      _requestSubscription = null;
      _listeningDriverId = null;
      TripService.instance.clearIncomingRequest();
      return;
    }
    final profile = DriverProfileService.instance.profile.value;
    if (!EnvConfig.previewMode && !profile.canListenForRideRequests) {
      _listeningDriverId = null;
      unawaited(_requestSubscription?.cancel());
      _requestSubscription = null;
      TripService.instance.incomingRequest.value = null;
      return;
    }
    final driverId = profile.id.isNotEmpty
        ? profile.id
        : AuthService.instance.currentUserId ?? 'preview-driver';
    if (_listeningDriverId == driverId) return;
    _listeningDriverId = driverId;
    unawaited(_requestSubscription?.cancel());
    _requestSubscription = _rideRepository
        .watchIncomingRequest(driverId)
        .listen(
          (request) {
            final previousRequestId = TripService.instance.incomingRequest.value?.requestId;
            if (request != null && request.requestId != previousRequestId) {
              unawaited(
                NotificationService.instance.showIncomingRideAlert(
                  request.requestId,
                ),
              );
            }
            TripService.instance.incomingRequest.value = request;
          },
          onError: (Object error) {
            errorTick.value++;
          },
        );
  }
}
