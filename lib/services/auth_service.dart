import 'package:firebase_auth/firebase_auth.dart';

import '../config/env_config.dart';
import '../config/firebase_config.dart';
import '../data/models/app_enums.dart';
import '../data/models/auth_user.dart';
import '../data/models/driver_profile.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/driver_repository.dart';
import '../data/repositories/ride_repository.dart';
import '../router/route_names.dart';
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
    final user = await _authRepository.signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
    );
    await _driverRepository.seedDriverProfile(
      uid: user.uid,
      fullName: fullName,
      phoneNumber: phoneNumber,
      email: email,
    );
    return RouteNames.profileSetup;
  }

  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final user = await _authRepository.signInWithEmail(
      email: email,
      password: password,
    );
    return landingRouteForUser(user.uid);
  }

  Future<String> signInWithGoogle() async {
    final user = await _authRepository.signInWithGoogle();
    final profile = await _driverRepository.getProfile(user.uid);
    if (profile == null) {
      await _driverRepository.seedDriverProfile(
        uid: user.uid,
        fullName: user.displayName.isNotEmpty ? user.displayName : 'Driver',
        phoneNumber: user.phoneNumber,
        email: user.email,
      );
      return RouteNames.profileSetup;
    }
    return landingRouteForUser(user.uid);
  }

  Future<String> landingRouteForCurrentUser() async {
    if (EnvConfig.previewMode) return RouteNames.dashboard;
    if (!FirebaseConfig.isAvailable) {
      return FirebaseConfig.useMockFallback
          ? RouteNames.onboarding
          : RouteNames.onboarding;
    }
    final user = currentUser;
    if (user == null) return RouteNames.onboarding;
    return landingRouteForUser(user.uid);
  }

  Future<String> landingRouteForUser(String uid) async {
    final profile = await _driverRepository.getProfile(uid);
    if (profile == null) return RouteNames.profileSetup;

    DriverProfileService.instance.profile.value = profile;
    DriverVerificationService.instance.syncStatus(profile.verificationStatus);

    if (profile.accountStatus == 'suspended' ||
        profile.accountStatus == 'blocked') {
      return RouteNames.suspended;
    }

    if (profile.verificationStatus == DriverVerificationStatus.approved) {
      if (profile.currentRideId != null && profile.currentRideStatus != null) {
        final trip = await RideRepository().getRide(profile.currentRideId!);
        if (trip != null) {
          TripService.instance.activeTrip.value = trip;
          return switch (profile.currentRideStatus) {
            'accepted' || 'driver_assigned' || 'driver_arriving' => RouteNames.goToPickup,
            'arrived' || 'driver_arrived' => RouteNames.pickupConfirmed,
            'ongoing' || 'in_progress' => RouteNames.tripInProgress,
            _ => RouteNames.dashboard,
          };
        }
      }
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
    await _authRepository.signOut();
  }

  String friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' => 'An account already exists with this email.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' =>
          'Use a stronger password with at least 6 characters.',
        'invalid-credential' ||
        'user-not-found' ||
        'wrong-password' => 'The email or password is incorrect.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        _ => error.message ?? 'Authentication failed. Please try again.',
      };
    }
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Access denied. You do not have permission to perform this action.';
      }
      return error.message ?? 'A database error occurred. Please try again.';
    }
    final errorStr = error.toString();
    if (errorStr.contains('permission-denied') || errorStr.contains('Permission denied')) {
      return 'Access denied. You do not have permission to perform this action.';
    }
    if (errorStr.contains('Null check operator used on null') ||
        errorStr.contains('NullIsLessThan') ||
        errorStr.contains('is not subtype of')) {
      return 'An unexpected data error occurred. Please reload and try again.';
    }
    if (errorStr.contains('API key') || errorStr.contains('not authorized')) {
      return 'Configuration error. Please contact support.';
    }
    return errorStr.replaceFirst('Exception: ', '');
  }

  String _routeForProfile(DriverProfile profile) {
    if (profile.accountStatus == 'suspended' ||
        profile.accountStatus == 'blocked') {
      return RouteNames.suspended;
    }
    return switch (profile.verificationStatus.name) {
      'pending' => RouteNames.pending,
      'approved' => RouteNames.dashboard,
      'rejected' || 'resubmissionRequired' => RouteNames.profileSetup,
      _ => RouteNames.profileSetup,
    };
  }
}
