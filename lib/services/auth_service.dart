import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../config/env_config.dart';
import '../config/firebase_config.dart';
import '../data/models/app_enums.dart';
import '../data/models/auth_user.dart';
import '../data/models/driver_profile.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/driver_repository.dart';
import '../data/repositories/driver_verification_repository.dart';
import '../data/repositories/ride_repository.dart';
import '../router/route_names.dart';
import 'auth_sync_service.dart';
import 'biometric_service.dart';
import 'app_lock_service.dart';
import 'driver_profile_service.dart';
import 'driver_verification_service.dart';
import 'firebase_storage_service.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'registration_draft_service.dart';
import 'trip_service.dart';

class AuthService {
  AuthService._();

  static final instance = AuthService._();

  final AuthRepository _authRepository = AuthRepository();
  final DriverRepository _driverRepository = DriverRepository();
  final DriverVerificationRepository _verificationRepository =
      DriverVerificationRepository();
  final FirebaseStorageService _storageService = FirebaseStorageService();

  AuthUser? get currentUser => _authRepository.currentUser;
  String? get currentUserId => currentUser?.uid;

  Stream<AuthUser?> authStateChanges() => _authRepository.authStateChanges();

  Future<String> signUp({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
  }) async {
    debugPrint('[driver-signup-draft] email=$email');
    RegistrationDraftService.instance.updateSignupCredentials(
      fullName: fullName,
      phoneNumber: phoneNumber,
      email: email,
      password: password,
      acceptedTerms: true,
    );
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
      try {
        user = await _authRepository.signInWithEmail(
          email: email,
          password: password,
        );
      } on FirebaseAuthException {
        throw StateError(
          'This email already has an account. Log in to continue your driver registration.',
        );
      }
      debugPrint('[driver-auth-created] uid=${user.uid} (recovered existing)');
    }
    // Best-effort node-api sync (Phase 4) - never blocks sign-up if it fails; the
    // Firestore-direct seed below is still the flow this app actually depends on.
    unawaited(AuthSyncService.instance.syncSession(displayName: fullName));
    // Idempotent: only creates documents that don't exist yet.
    await _driverRepository.seedDriverProfile(
      uid: user.uid,
      fullName: fullName.trim().isNotEmpty
          ? fullName
          : (user.displayName.isNotEmpty ? user.displayName : 'Driver'),
      phoneNumber: phoneNumber,
      email: email,
    );
    final route = RouteNames.profileSetup;
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
      // Best-effort node-api sync (Phase 4) - repairs a missing node-api users/{uid} record for
      // an account that predates this sync existing; never blocks login if it fails.
      unawaited(AuthSyncService.instance.syncSession());
      // Ensure both users/{uid} and drivers/{uid} exist (idempotent — no-op
      // when documents are already present; repairs any partial signup state).
      final existingProfile = await _driverRepository.getProfile(user.uid);
      if (existingProfile == null) {
        await _driverRepository.seedDriverProfile(
          uid: user.uid,
          fullName: user.displayName.isNotEmpty ? user.displayName : 'Driver',
          phoneNumber: user.phoneNumber,
          email: user.email,
        );
      } else {
        await _driverRepository.ensureDriverUserRecord(
          authUid: user.uid,
          fullName: existingProfile.fullName.isNotEmpty
              ? existingProfile.fullName
              : user.displayName,
          phoneNumber: existingProfile.phone.isNotEmpty
              ? existingProfile.phone
              : user.phoneNumber,
          email: existingProfile.email.isNotEmpty
              ? existingProfile.email
              : user.email,
        );
      }
      final profile =
          existingProfile ?? await _driverRepository.getProfile(user.uid);
      await _driverRepository.recordLogin(user.uid, driverId: profile?.id);
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

  Future<String> finalizeDriverOnboarding(RegistrationDraft draft) async {
    if (!draft.isComplete) {
      throw StateError('Complete every onboarding step before submitting.');
    }

    AuthUser? user = currentUser;
    if (user == null) {
      if (!draft.hasSignupCredentials) {
        throw StateError(
          'Please log in again to finish your driver registration.',
        );
      }
      try {
        user = await _authRepository.signUpWithEmail(
          email: draft.email,
          password: draft.password,
          fullName: draft.fullName,
        );
        debugPrint('[driver-finalize-auth-created] uid=${user.uid}');
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') rethrow;
        try {
          user = await _authRepository.signInWithEmail(
            email: draft.email,
            password: draft.password,
          );
        } on FirebaseAuthException {
          throw StateError(
            'Please log in again to finish your driver registration.',
          );
        }
        debugPrint('[driver-finalize-auth-recovered] uid=${user.uid}');
      }
    }

    await _driverRepository.seedDriverProfile(
      uid: user.uid,
      fullName: draft.fullName,
      phoneNumber: draft.phoneNumber,
      email: draft.email,
    );
    await _driverRepository.saveProfileSetup(
      uid: user.uid,
      fullName: draft.fullName,
      phoneNumber: draft.phoneNumber,
      email: draft.email,
      vehicleType: draft.vehicleType,
      vehicleModel: draft.vehicleModel,
      vehiclePlateNumber: draft.vehiclePlateNumber,
      vehicleColor: draft.vehicleColor,
      numberOfSeats: draft.numberOfSeats,
      cityRegion: draft.cityRegion,
      payoutProvider: draft.payoutProvider,
      payoutAccountName: draft.payoutAccountName,
      payoutAccountNumber: draft.payoutAccountNumber,
    );

    final uploadedDraft = await _uploadVerificationDraft(user.uid, draft);
    await _verificationRepository.submit(uid: user.uid, draft: uploadedDraft);
    DriverVerificationService.instance.submit();
    await _driverRepository.recordLogin(user.uid);
    final canonicalProfile =
        await AuthSyncService.instance.createDriverApplication(
      regionId: draft.regionId ?? draft.cityRegion,
      affiliationType: draft.affiliationType,
      serviceTypes: draft.serviceTypes,
      vehicleCategory: draft.vehicleCategory,
    );
    RegistrationDraftService.instance.clear();
    if (canonicalProfile?['regionLaunchStatus']?.toString().toUpperCase() ==
        'WAITING_FOR_LAUNCH') {
      return RouteNames.comingSoon;
    }
    return RouteNames.pending;
  }

  Future<RegistrationDraft> _uploadVerificationDraft(
    String uid,
    RegistrationDraft draft,
  ) async {
    final nationalIdFrontPath = await _uploadDraftImage(
      uid: uid,
      storageFileName: 'national_id_front.jpg',
      bytes: draft.nationalIdPhotoBytes,
      localPath: draft.nationalIdPhotoPath,
    );
    final nationalIdBackPath = await _uploadDraftImage(
      uid: uid,
      storageFileName: 'national_id_back.jpg',
      bytes: draft.nationalIdBackPhotoBytes,
      localPath: draft.nationalIdBackPhotoPath,
    );
    final licencePath = await _uploadDraftImage(
      uid: uid,
      storageFileName: 'driver_licence.jpg',
      bytes: draft.driverLicencePhotoBytes,
      localPath: draft.driverLicencePhotoPath,
    );
    final selfiePath = await _uploadDraftImage(
      uid: uid,
      storageFileName: 'selfie.jpg',
      bytes: draft.selfieBytes,
      localPath: draft.selfiePhotoPath == 'live_selfie_pending.jpg'
          ? null
          : draft.selfiePhotoPath,
    );

    return draft.copyWith(
      nationalIdPhotoPath: nationalIdFrontPath,
      nationalIdBackPhotoPath: nationalIdBackPath,
      driverLicencePhotoPath: licencePath,
      selfiePhotoPath: selfiePath,
      clearNationalIdBytes: true,
      clearNationalIdBackBytes: true,
      clearDriverLicenceBytes: true,
      clearSelfieBytes: true,
    );
  }

  Future<String> _uploadDraftImage({
    required String uid,
    required String storageFileName,
    Uint8List? bytes,
    String? localPath,
  }) {
    final storagePath = 'driver_verifications/$uid/$storageFileName';
    if (bytes != null && bytes.isNotEmpty) {
      return _storageService.uploadBytes(bytes: bytes, path: storagePath);
    }
    if (localPath != null && localPath.isNotEmpty) {
      if (localPath.startsWith('driver_verifications/')) {
        return Future.value(localPath);
      }
      return _storageService.uploadFile(
        file: XFile(localPath),
        path: storagePath,
      );
    }
    throw StateError('Missing verification image.');
  }

  Future<String> completeRequiredPasswordChange(String newPassword) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Sign in before changing password.');
    if (newPassword.trim().length < 6) {
      throw StateError('Use a stronger password with at least 6 characters.');
    }
    await _authRepository.updateCurrentPassword(newPassword.trim());
    final profile = await _driverRepository.getProfile(uid);
    await _driverRepository.markPasswordChanged(profile?.id ?? uid);
    return landingRouteForUser(uid);
  }

  Future<String> signInWithGoogle() async {
    debugPrint('[driver-google-start]');
    try {
      final user = await _authRepository.signInWithGoogle();
      debugPrint('[driver-google-success] uid=${user.uid}');
      unawaited(
        AuthSyncService.instance.syncSession(displayName: user.displayName),
      );
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
    // Best-effort node-api sync (Phase 4) - repairs a missing node-api users/{uid} record on
    // every cold start; never blocks routing if it fails.
    unawaited(AuthSyncService.instance.syncSession());
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

    final fleetId = profile.currentFleetId ?? profile.fleetId;
    final fleetInfo = fleetId == null || fleetId.trim().isEmpty
        ? null
        : await _driverRepository.getFleetInfo(fleetId);
    DriverProfileService.instance.fleetInfo.value = fleetInfo;

    if (profile.isSuspended || fleetInfo?.isSuspended == true) {
      debugPrint(
        '[driver-route-decision] destination=${RouteNames.suspended} '
        'reason=${profile.isSuspended ? 'account' : 'fleet'}_suspended',
      );
      return RouteNames.suspended;
    }
    if (profile.isWaitingForRegionLaunch) {
      debugPrint(
        '[driver-route-decision] destination=${RouteNames.comingSoon} '
        'reason=region_waiting_for_launch',
      );
      return RouteNames.comingSoon;
    }

    if (profile.mustChangePassword) {
      debugPrint(
        '[driver-route-decision] destination=${RouteNames.changePassword} '
        'reason=must_change_password',
      );
      return RouteNames.changePassword;
    }

    if (profile.verificationStatus == DriverVerificationStatus.approved) {
      if (profile.currentRideId != null && profile.currentRideStatus != null) {
        final trip = await RideRepository().getRide(profile.currentRideId!);
        if (trip != null) {
          TripService.instance.activeTrip.value = trip;
          final dest = switch (profile.currentRideStatus) {
            'accepted' ||
            'driver_assigned' ||
            'driver_arriving' =>
              RouteNames.goToPickup,
            'arrived' || 'driver_arrived' => RouteNames.pickupConfirmed,
            'ongoing' || 'in_progress' => RouteNames.tripInProgress,
            _ => RouteNames.dashboard,
          };
          debugPrint(
            '[driver-route-decision] destination=$dest reason=active_ride',
          );
          return _secureRoute(dest);
        }
      }
      debugPrint(
        '[driver-route-decision] destination=${RouteNames.dashboard} reason=approved',
      );
      return _secureRoute(RouteNames.dashboard);
    }

    return _secureRoute(_routeForProfile(profile));
  }

  Future<void> signOut() async {
    final uid = currentUserId;
    if (uid != null) {
      final profile = DriverProfileService.instance.profile.value;
      final driverId = profile.id.isNotEmpty ? profile.id : uid;
      await LocationService.instance.stopDriverTracking(uid: driverId);
      await _driverRepository.setOffline(driverId);
    }
    await NotificationService.instance.clear();
    await DriverProfileService.instance.unbind();
    // Per-device biometric enrollment stays intact (re-signing into the same
    // account on this device shouldn't force re-enabling it) — only the
    // "last signed-in uid" pointer the biometric lock screen reads at
    // startup is cleared, so a signed-out device never auto-offers a
    // biometric unlock for an account nobody is in.
    await BiometricService.instance.forgetLastUid();
    AppLockService.instance.markLocked();
    await _authRepository.signOut();
  }

  String friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' =>
          'This email already has an account. Log in to continue your driver registration.',
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
        'user-disabled' => 'This account has been disabled. Contact support.',
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
        return 'We could not save your driver profile. Please try again.';
      }
      if (error.code == 'unavailable') {
        return 'You appear to be offline. Check your internet connection and try again.';
      }
      return error.message ?? 'A database error occurred. Please try again.';
    }
    final errorStr = error.toString();
    if (errorStr.contains('permission-denied') ||
        errorStr.contains('Permission denied')) {
      return 'We could not save your driver profile. Please try again.';
    }
    if (errorStr.contains('approved before going online') ||
        errorStr.contains('must be approved')) {
      return 'Your account must be approved before going online.';
    }
    if (errorStr.contains('commission balance') ||
        errorStr.contains('Top up your commission')) {
      return 'Top up your commission balance to receive rides.';
    }
    if (errorStr.contains('Unlock your driver account')) {
      return 'Unlock your driver account before continuing.';
    }
    if (errorStr.contains('Awaiting approval')) {
      return 'Awaiting administrator approval.';
    }
    if (errorStr.contains('Fleet Temporarily Suspended')) {
      return 'Fleet Temporarily Suspended. Ride requests are temporarily unavailable.';
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
      return 'You appear to be offline. Check your internet connection and try again.';
    }
    return errorStr
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }

  String _routeForProfile(DriverProfile profile) {
    if (profile.isSuspended || DriverProfileService.instance.isFleetSuspended) {
      debugPrint(
        '[driver-route-decision] destination=${RouteNames.suspended} '
        'reason=account_${profile.rawStatus ?? profile.accountStatus}',
      );
      return RouteNames.suspended;
    }
    if (profile.isWaitingForRegionLaunch) return RouteNames.comingSoon;
    final dest = switch (profile.verificationStatus.name) {
      'pending' => RouteNames.pending,
      'approved' => RouteNames.dashboard,
      // rejected/resubmissionRequired: show pending screen with feedback.
      'rejected' || 'resubmissionRequired' => RouteNames.pending,
      'inProgress' => switch (profile.onboardingStep) {
          'licence' => RouteNames.licence,
          'selfie' => RouteNames.selfie,
          'review' => RouteNames.review,
          'submitted' => RouteNames.pending,
          _ => RouteNames.nationalId,
        },
      _ => RouteNames.profileSetup, // notStarted
    };
    debugPrint(
      '[driver-route-decision] destination=$dest '
      'reason=verificationStatus_${profile.verificationStatus.name}',
    );
    return dest;
  }

  String _secureRoute(String route) {
    if (route == RouteNames.appLock ||
        route == RouteNames.login ||
        route == RouteNames.onboarding ||
        route == RouteNames.changePassword) {
      return route;
    }
    if (AppLockService.instance.unlockedSession) return route;
    AppLockService.instance.setPendingRoute(route);
    return RouteNames.appLock;
  }
}
