import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app/therain_driver_app.dart';
import '../config/env_config.dart';
import '../config/firebase_config.dart';
import '../data/mock/mock_driver_profile.dart';
import '../data/models/app_enums.dart';
import '../data/models/driver_profile.dart';
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
  final ValueNotifier<DriverProfile> profile = ValueNotifier(mockDriverProfile);
  StreamSubscription<DriverProfile?>? _profileSubscription;
  String? _boundUid;

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
      profile.value = value;
      DriverVerificationService.instance.syncStatus(value.verificationStatus);

      if (value.accountStatus == 'suspended' ||
          value.accountStatus == 'blocked') {
        final navState = TheRainDriverApp.navigatorKey.currentState;
        if (navState != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navState.pushNamedAndRemoveUntil(
              RouteNames.suspended,
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
    });
  }

  Future<void> unbind() async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _boundUid = null;
    profile.value = mockDriverProfile;
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

    if (nextOnline) {
      await LocationService.instance.ensurePermission();
      await _repository.setOnline(uid: uid, isOnline: true);
      try {
        await LocationService.instance.startDriverTracking(
          uid: uid,
          currentRideId: profile.value.currentRideId,
          vehicleType: profile.value.vehicleType,
        );
      } catch (_) {
        await _repository.setOffline(uid);
        rethrow;
      }
    } else {
      if (profile.value.currentRideId != null) {
        throw StateError('You cannot go offline during an active ride.');
      }
      await LocationService.instance.stopDriverTracking(uid: uid);
      await _repository.setOnline(uid: uid, isOnline: false);
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
