import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app/therain_driver_app.dart';
import '../config/env_config.dart';
import '../config/firebase_config.dart';
import '../data/mock/mock_driver_profile.dart';
import '../data/models/app_enums.dart';
import '../data/models/driver_profile.dart';
import '../data/models/fleet_info.dart';
import '../data/repositories/driver_repository.dart';
import '../router/route_names.dart';
import 'auth_service.dart';
import 'driver_verification_service.dart';
import 'location_service.dart';
import 'notification_service.dart';

class DriverProfileService {
  DriverProfileService._();

  static final instance = DriverProfileService._();

  final DriverRepository _repository = DriverRepository();
  final ValueNotifier<DriverProfile> profile = ValueNotifier(_emptyProfile);

  /// Driver Identification: automatically resolved (no manual selection) the
  /// moment the bound driver profile turns out to carry a `fleetId`. Null for
  /// TheRain-direct drivers, or while the lookup is in flight.
  final ValueNotifier<FleetInfo?> fleetInfo = ValueNotifier(null);

  StreamSubscription<DriverProfile?>? _profileSubscription;
  String? _boundUid;
  String? _fleetInfoFleetId;

  Future<void> bindAuthenticatedDriver() async {
    final uid = AuthService.instance.currentUserId;
    if (uid == null) {
      await unbind();
      return;
    }
    if (uid == _boundUid) return;
    await _profileSubscription?.cancel();
    _boundUid = uid;
    await NotificationService.instance.initializeForDriver(uid);
    _profileSubscription = _repository.watchProfile(uid).listen((value) {
      if (value == null) return;
      final wasSuspended = profile.value.isSuspended;
      profile.value = value;
      DriverVerificationService.instance.syncStatus(value.verificationStatus);

      if (value.isSuspended) {
        final navState = TheRainDriverApp.navigatorKey.currentState;
        if (navState != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navState.pushNamedAndRemoveUntil(
              RouteNames.suspended,
              (_) => false,
            );
          });
        }
      } else if (wasSuspended) {
        // Appeal approved (or an admin manually restored the account) while
        // the app was sitting on the suspended screen — the real-time
        // Firestore listener picks up the status flip instantly, so bounce
        // the driver straight back into the app instead of leaving them
        // stranded on a stale "Account Suspended" screen.
        final navState = TheRainDriverApp.navigatorKey.currentState;
        if (navState != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navState.pushNamedAndRemoveUntil(
              RouteNames.dashboard,
              (_) => false,
            );
          });
        }
      }

      if (value.onlineStatus == DriverOnlineStatus.online &&
          !LocationService.instance.isTracking) {
        LocationService.instance
            .startDriverTracking(
              uid: uid,
              currentRideId: value.currentRideId,
              vehicleType: value.vehicleType,
            )
            .catchError((Object error) {
              debugPrint('Could not restore driver tracking: $error');
            });
      }

      _syncFleetInfo(value.fleetId);
    });
  }

  /// Refetches fleet info only when the linked fleetId actually changes
  /// (not on every profile stream tick) — cheap no-op for TheRain-direct
  /// drivers, who never have a fleetId to begin with.
  Future<void> _syncFleetInfo(String? fleetId) async {
    if (fleetId == _fleetInfoFleetId) return;
    _fleetInfoFleetId = fleetId;
    if (fleetId == null || fleetId.trim().isEmpty) {
      fleetInfo.value = null;
      return;
    }
    try {
      fleetInfo.value = await _repository.getFleetInfo(fleetId);
    } catch (error) {
      debugPrint('Could not load fleet info: $error');
    }
  }

  Future<void> unbind() async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _boundUid = null;
    _fleetInfoFleetId = null;
    fleetInfo.value = null;
    profile.value = EnvConfig.previewMode ? mockDriverProfile : _emptyProfile;
  }

  Future<void> toggleOnline() async {
    final currentlyOnline =
        profile.value.onlineStatus != DriverOnlineStatus.offline;
    final nextOnline = !currentlyOnline;
    final uid = AuthService.instance.currentUserId;

    if (uid == null) {
      if (!EnvConfig.previewMode) {
        throw StateError('Sign in before going online.');
      }
      profile.value = profile.value.copyWith(
        onlineStatus: nextOnline
            ? DriverOnlineStatus.online
            : DriverOnlineStatus.offline,
      );
      return;
    }

    debugPrint(
      '[driver-go-online-check] uid=$uid '
      'nextOnline=$nextOnline '
      'verificationStatus=${profile.value.verificationStatus.name} '
      'canReceiveRides=${profile.value.canReceiveRides}',
    );

    if (nextOnline) {
      await LocationService.instance.ensurePermission();
      await _repository.setOnline(uid: uid, isOnline: true);
      try {
        await LocationService.instance.startDriverTracking(
          uid: uid,
          currentRideId: profile.value.currentRideId,
          vehicleType: profile.value.vehicleType,
        );
        debugPrint('[driver-go-online-success] uid=$uid');
      } catch (e) {
        debugPrint('[driver-go-online-blocked] uid=$uid reason=$e');
        await _repository.setOffline(uid);
        rethrow;
      }
    } else {
      if (profile.value.currentRideId != null) {
        debugPrint('[driver-go-online-blocked] uid=$uid reason=active_ride');
        throw StateError('You cannot go offline during an active ride.');
      }
      await LocationService.instance.stopDriverTracking(uid: uid);
      await _repository.setOnline(uid: uid, isOnline: false);
      debugPrint('[driver-go-online-success] uid=$uid went_offline=true');
    }
  }

  Future<void> restoreTrackingIfNeeded() async {
    final uid = AuthService.instance.currentUserId;
    if (uid == null ||
        profile.value.onlineStatus == DriverOnlineStatus.offline ||
        LocationService.instance.isTracking) {
      return;
    }
    await LocationService.instance.startDriverTracking(
      uid: uid,
      currentRideId: profile.value.currentRideId,
      vehicleType: profile.value.vehicleType,
    );
  }

  Future<void> updateContact({
    required String fullName,
    required String phone,
    required String email,
  }) async {
    final uid = AuthService.instance.currentUserId;
    if (uid != null && FirebaseConfig.isAvailable) {
      await _repository.updateProfile(
        uid: uid,
        fullName: fullName,
        phoneNumber: phone,
        email: email,
      );
    }
    profile.value = profile.value.copyWith(
      fullName: fullName,
      phone: phone,
      email: email,
    );
  }
}

const _emptyProfile = DriverProfile(
  id: '',
  fullName: 'Driver',
  phone: '',
  email: '',
  rating: 0,
  totalTrips: 0,
  onlineStatus: DriverOnlineStatus.offline,
  verificationStatus: DriverVerificationStatus.notStarted,
);
