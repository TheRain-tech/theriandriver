import 'package:flutter/foundation.dart';

import '../config/firebase_config.dart';
import 'api_client.dart';

/// Synchronizes the signed-in Firebase identity with node-api - the canonical backend - per
/// therainAdmin/docs/platform/phase-4/DRIVER_AUTH_FLOW.md. This runs alongside (not instead of)
/// the existing Firestore-direct `DriverRepository`/`AuthService` flow: every call here is
/// best-effort and non-fatal (network hiccups must never block sign-in/sign-up, since the
/// existing Firestore-backed flow still works on its own). What this closes is the specific gap
/// section 10/11 of the Phase 4 brief calls out - "Firebase users synchronize with node-api" and
/// "existing Firebase users with missing profiles are repaired" - without attempting a full
/// rewrite of the much larger existing onboarding/profile read-write surface in this same pass
/// (see PHASE_4_IMPLEMENTATION_REPORT.md for what remains). Uses the app's existing
/// lib/services/api_client.dart (already used by DriverRevenueRepository/FleetRelationsRepository
/// for the same "go through node-api, not direct Firestore" pattern) rather than a second HTTP
/// client.
class AuthSyncService {
  AuthSyncService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  static final instance = AuthSyncService();

  final ApiClient _client;

  /// POST /api/auth/sync - idempotent upsert of users/{uid} on node-api, keyed off the verified
  /// Firebase ID token (never a client-supplied uid). Safe to call on every sign-in/sign-up.
  /// Returns true on success, false on any failure (network, node-api down, etc.) - callers must
  /// never treat a false return as fatal.
  Future<bool> syncSession({String? displayName}) async {
    if (!FirebaseConfig.isAvailable) return false;
    try {
      await _client.post(
        '/api/auth/sync',
        body: {
          if (displayName != null && displayName.trim().isNotEmpty)
            'displayName': displayName.trim(),
        },
      );
      return true;
    } catch (error) {
      debugPrint('[driver-auth-sync-failed] error=$error');
      return false;
    }
  }

  /// GET /api/drivers/me - the driver's canonical node-api profile, if one exists. Returns null
  /// both when no profile exists yet (a brand-new Firebase user who hasn't started onboarding
  /// through node-api) and on any network/server failure - callers distinguish those two cases
  /// by falling back to the existing Firestore-direct profile read, not by inspecting this
  /// method's return value alone.
  Future<Map<String, dynamic>?> fetchMyDriverProfile() async {
    if (!FirebaseConfig.isAvailable) return null;
    try {
      final data = await _client.get('/api/drivers/me');
      return data is Map<String, dynamic> ? data : null;
    } on ApiException catch (error) {
      if (!error.isNotFound) {
        debugPrint('[driver-auth-sync-me-failed] error=$error');
      }
      return null;
    } catch (error) {
      debugPrint('[driver-auth-sync-me-failed] error=$error');
      return null;
    }
  }

  /// POST /api/drivers/apply - creates the initial node-api driver record (idempotent: node-api
  /// returns the existing record unchanged if one already exists and isn't REJECTED). Only
  /// regionId is required; every other canonical taxonomy field is optional here and can be
  /// filled in later via PATCH /api/drivers/me/onboarding as the driver completes each step.
  Future<Map<String, dynamic>?> createDriverApplication({
    required String regionId,
    String? affiliationType,
    List<String>? serviceTypes,
    String? vehicleCategory,
  }) async {
    if (!FirebaseConfig.isAvailable) return null;
    try {
      final data = await _client.post(
        '/api/drivers/apply',
        body: {
          'regionId': regionId,
          'affiliationType': ?affiliationType,
          'serviceTypes': ?serviceTypes,
          'vehicleCategory': ?vehicleCategory,
        },
      );
      return data is Map<String, dynamic> ? data : null;
    } catch (error) {
      debugPrint('[driver-auth-sync-apply-failed] error=$error');
      return null;
    }
  }
}
