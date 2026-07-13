import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/env_config.dart';
import '../config/firebase_config.dart';
import '../data/models/app_enums.dart';
import '../data/models/auth_user.dart';
import '../data/models/driver_profile.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/driver_repository.dart';
import '../data/repositories/ride_repository.dart';
import '../router/route_names.dart';
import 'biometric_service.dart';
import 'driver_profile_service.dart';
import 'driver_verification_service.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'trip_service.dart';

class AuthService {
  AuthService._();

  static final instance = AuthService._();

  final AuthRepository _authRepository = AuthRepository();
  final DriverRepository _driverRepository = DriverRepository();

  AuthUser? get currentUser => _authRepository.currentUser;
  String? get currentUserId => currentUser?.uid;

  Stream<AuthUser?> authStateChanges() => _authRepository.authStateChanges();

  Future<String> signUp({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
  }) async {
    debugPrint('[driver-signup-start] email=$email');
    AuthUser user;
    try {
      user = await _authRepository.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );
      debugPrint('[driver-auth-created] uid=${user.uid}');
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') {
        debugPrint('[driver-signup-fail] code=${e.code} message=${e.message}');
        rethrow;
      }
      // Account already exists — sign in and continue onboarding from
      // wherever they left off (handles retry after a partial signup failure).
      user = await _authRepository.signInWithEmail(
        email: email,
        password: password,
      );
      debugPrint('[driver-auth-created] uid=${user.uid} (recovered existing)');
    }
    // Idempotent: only creates documents that don't exist yet.
    await _driverRepository.seedDriverProfile(
      uid: user.uid,
      fullName: fullName.trim().isNotEmpty
          ? fullName
          : (user.displayName.isNotEmpty ? user.displayName : 'Driver'),
      phoneNumber: phoneNumber,
      email: email,
    );
    final route = await landingRouteForUser(user.uid);
    debugPrint('[driver-signup-route] uid=${user.uid} destination=$route');
    return route;
  }

  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    debugPrint('[driver-login-start] email=$email');
    try {
      final user = await _authRepository.signInWithEmail(
        email: email,
        password: password,
      );
      debugPrint('[driver-login-success] uid=${user.uid}');
      // Ensure both users/{uid} and drivers/{uid} exist (idempotent — no-op
      // when documents are already present; repairs any partial signup state).
      await _driverRepository.seedDriverProfile(
        uid: user.uid,
        fullName: user.displayName.isNotEmpty ? user.displayName : 'Driver',
        phoneNumber: user.phoneNumber,
        email: user.email,
      );
      await _driverRepository.recordLogin(user.uid);
      final route = await landingRouteForUser(user.uid);
      debugPrint(
        '[driver-login-profile-route] uid=${user.uid} destination=$route',
      );
      return route;
    } catch (e) {
      if (e is FirebaseAuthException) {
        debugPrint('[driver-login-fail] code=${e.code} message=${e.message}');
      } else {
        debugPrint('[driver-login-fail] error=$e');
      }
      rethrow;
    }
  }

  Future<String> signInWithGoogle() async {
    debugPrint('[driver-google-start]');
    try {
      final user = await _authRepository.signInWithGoogle();
      debugPrint('[driver-google-success] uid=${user.uid}');
      await _driverRepository.seedDriverProfile(
        uid: user.uid,
        fullName: user.displayName.isNotEmpty ? user.displayName : 'Driver',
        phoneNumber: user.phoneNumber,
        email: user.email,
      );
      await _driverRepository.recordLogin(user.uid);
      return landingRouteForUser(user.uid);
    } catch (e) {
      if (e is FirebaseAuthException) {
        debugPrint('[driver-google-fail] code=${e.code} message=${e.message}');
      } else {
        debugPrint('[driver-google-fail] error=$e');
      }
      rethrow;
    }
  }

  Future<String> landingRouteForCurrentUser() async {
    if (EnvConfig.previewMode) return RouteNames.dashboard;
    if (!FirebaseConfig.isAvailable) {
      throw StateError(
        'TheRain Driver could not connect to Firebase. Try again shortly.',
      );
    }
    final user = currentUser;
    debugPrint('[driver-auth-state] uid=${user?.uid ?? 'null'}');
    if (user == null) return RouteNames.onboarding;
    // On cold start, ensure all Firestore documents exist before routing.
    // Repairs any partial-signup state without overwriting good data.
    await _driverRepository.seedDriverProfile(
      uid: user.uid,
      fullName: user.displayName.isNotEmpty ? user.displayName : 'Driver',
      phoneNumber: user.phoneNumber,
      email: user.email,
    );
    return landingRouteForUser(user.uid);
  }

  Future<void> resetPassword(String email) =>
      _authRepository.sendPasswordResetEmail(email);

  Future<String> landingRouteForUser(String uid) async {
    debugPrint('[driver-profile-load-start] uid=$uid');
    final profile = await _driverRepository.getProfile(uid);
    if (profile == null) {
      debugPrint('[driver-profile-missing] uid=$uid');
      return RouteNames.profileSetup;
    }

    debugPrint(
      '[driver-profile-load-success] uid=$uid '
      'verificationStatus=${profile.verificationStatus.name} '
      'accountStatus=${profile.accountStatus}',
    );

    DriverProfileService.instance.profile.value = profile;
    DriverVerificationService.instance.syncStatus(profile.verificationStatus);

    if (profile.isSuspended) {
      debugPrint(
        '[driver-route-decision] destination=${RouteNames.suspended} '
        'reason=account_${profile.rawStatus ?? profile.accountStatus}',
      );
      return RouteNames.suspended;
    }

    if (profile.verificationStatus == DriverVerificationStatus.approved) {
      if (profile.currentRideId != null && profile.currentRideStatus != null) {
        final trip = await RideRepository().getRide(profile.currentRideId!);
        if (trip != null) {
          TripService.instance.activeTrip.value = trip;
          final dest = switch (profile.currentRideStatus) {
            'accepted' ||
            'driver_assigned' ||
            'driver_arriving' => RouteNames.goToPickup,
            'arrived' || 'driver_arrived' => RouteNames.pickupConfirmed,
            'ongoing' || 'in_progress' => RouteNames.tripInProgress,
            _ => RouteNames.dashboard,
          };
          debugPrint(
            '[driver-route-decision] destination=$dest reason=active_ride',
          );
          return dest;
        }
      }
      debugPrint(
        '[driver-route-decision] destination=${RouteNames.dashboard} reason=approved',
      );
      return RouteNames.dashboard;
    }

    return _routeForProfile(profile);
  }

  Future<void> signOut() async {
    final uid = currentUserId;
    if (uid != null) {
      await LocationService.instance.stopDriverTracking(uid: uid);
      await _driverRepository.setOffline(uid);
    }
    await NotificationService.instance.clear();
    await DriverProfileService.instance.unbind();
    // Per-device biometric enrollment stays intact (re-signing into the same
    // account on this device shouldn't force re-enabling it) — only the
    // "last signed-in uid" pointer the biometric lock screen reads at
    // startup is cleared, so a signed-out device never auto-offers a
    // biometric unlock for an account nobody is in.
    await BiometricService.instance.forgetLastUid();
    await _authRepository.signOut();
  }

  String friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' =>
          'An account with this email already exists. Please log in to continue your driver registration.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' =>
          'Use a stronger password with at least 6 characters.',
        'user-not-found' =>
          'No account found with this email. Tap "Sign up" to create one.',
        'wrong-password' =>
          'Incorrect password. Try again or tap "Forgot password?".',
        'invalid-credential' => 'The email or password is incorrect.',
        'too-many-requests' =>
          'Too many failed attempts. Try again later or reset your password.',
        'user-disabled' =>
          'This account has been disabled. Contact support.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        'account-exists-with-different-credential' =>
          'An account already exists with this email using a different sign-in method.',
        'operation-not-allowed' =>
          'This sign-in method is not enabled yet. Contact support.',
        _ => error.message ?? 'Authentication failed. Please try again.',
      };
    }
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'We could not access your account data. Please check your connection and try again.';
      }
      if (error.code == 'unavailable') {
        return 'Service temporarily unavailable. Check your connection and try again.';
      }
      return error.message ?? 'A database error occurred. Please try again.';
    }
    final errorStr = error.toString();
    if (errorStr.contains('permission-denied') ||
        errorStr.contains('Permission denied')) {
      return 'We could not access your account data. Please check your connection and try again.';
    }
    if (errorStr.contains('approved before going online') ||
        errorStr.contains('must be approved')) {
      return 'Your account must be approved before going online.';
    }
    if (errorStr.contains('not configured')) {
      return 'This sign-in method is not available. Use email and password instead.';
    }
    if (errorStr.contains('Null check operator used on null') ||
        errorStr.contains('NullIsLessThan') ||
        errorStr.contains('is not subtype of')) {
      return 'An unexpected data error occurred. Please reload and try again.';
    }
    if (errorStr.contains('API key') || errorStr.contains('not authorized')) {
      return 'Configuration error. Please contact support.';
    }
    if (errorStr.contains('network') || errorStr.contains('Network')) {
      return 'Network error. Check your connection.';
    }
    return errorStr
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }

  String _routeForProfile(DriverProfile profile) {
    if (profile.isSuspended) {
      debugPrint(
        '[driver-route-decision] destination=${RouteNames.suspended} '
        'reason=account_${profile.rawStatus ?? profile.accountStatus}',
      );
      return RouteNames.suspended;
    }
    final dest = switch (profile.verificationStatus.name) {
      'pending' => RouteNames.pending,
      'approved' => RouteNames.dashboard,
      // rejected/resubmissionRequired: show pending screen with feedback.
      'rejected' || 'resubmissionRequired' => RouteNames.pending,
      // inProgress means profile setup was saved; resume at first KYC step.
      'inProgress' => RouteNames.nationalId,
      _ => RouteNames.profileSetup, // notStarted
    };
    debugPrint(
      '[driver-route-decision] destination=$dest '
      'reason=verificationStatus_${profile.verificationStatus.name}',
    );
    return dest;
  }
}
