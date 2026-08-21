import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../config/firebase_config.dart';
import '../../core/region/region_normalizer.dart';
import '../../core/utils/account_status.dart';
import '../../firebase/firestore_collections.dart';
import '../../services/api_client.dart';
import '../mock/mock_driver_profile.dart';
import '../models/driver_profile.dart';
import '../models/fleet_info.dart';

class DriverRepository {
  DriverRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _driverRef(String uid) =>
      _db.collection(FirestoreCollections.drivers).doc(uid);

  Future<DriverProfile?> getProfile(String uid) async {
    if (FirebaseConfig.useMockFallback) {
      return mockDriverProfile.copyWith();
    }
    if (!FirebaseConfig.isAvailable) return null;

    final byAuth = await findProfileForAuthUid(uid);
    if (byAuth != null) return byAuth;

    final snapshot = await _driverRef(uid).get();
    return _profileFromSnapshot(snapshot);
  }

  Future<DriverProfile?> findProfileForAuthUid(String authUid) async {
    if (FirebaseConfig.useMockFallback) return mockDriverProfile.copyWith();
    if (!FirebaseConfig.isAvailable) return null;

    final snapshot = await _db
        .collection(FirestoreCollections.drivers)
        .where('authUid', isEqualTo: authUid)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return DriverProfile.fromMap(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  }

  Stream<DriverProfile?> watchProfile(String uid) {
    if (FirebaseConfig.useMockFallback) {
      return Stream<DriverProfile?>.value(mockDriverProfile);
    }
    if (!FirebaseConfig.isAvailable) {
      return Stream<DriverProfile?>.value(null);
    }

    // Every node-api driver-creation path (applyAsDriver, createManagedDriver,
    // claimDriverInvitation) uses the driver's Firebase Auth uid as the
    // drivers/{uid} document ID directly - there is no real path where they
    // differ. Listening on the document by ID (instead of a where('authUid', ...)
    // query, which only this app's own self-registration write ever populates)
    // is what makes approval/status updates propagate live regardless of how
    // the driver's account was created - see the driver-approval investigation
    // this fixed: admin-created and fleet-invited drivers never got a live
    // update at all under the old query, so their app froze on whatever
    // status existed at the first snapshot even after a real admin approval.
    return _driverRef(uid).snapshots().map(_profileFromSnapshot);
  }

  DriverProfile? _profileFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return data == null ? null : DriverProfile.fromMap(data, snapshot.id);
  }

  Future<void> seedDriverProfile({
    required String uid,
    required String fullName,
    required String phoneNumber,
    required String email,
    required String cityRegion,
  }) async {
    if (!FirebaseConfig.isAvailable) return;

    final userRef = _db.collection(FirestoreCollections.users).doc(uid);
    final driverRef = _driverRef(uid);
    final verificationRef = _db
        .collection(FirestoreCollections.driverVerifications)
        .doc(uid);

    // Idempotent transaction: reads all three docs and only CREATEs whichever
    // are missing. Safe to call on every signup retry, login, and cold start.
    // Never overwrites existing data.
    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final driverSnap = await tx.get(driverRef);
      final verificationSnap = await tx.get(verificationRef);

      if (!userSnap.exists) {
        debugPrint('[driver-user-doc-created] uid=$uid');
        tx.set(userRef, {
          'uid': uid,
          'role': 'driver',
          'fullName': fullName.trim(),
          'phoneNumber': phoneNumber.trim(),
          'email': email.trim().toLowerCase(),
          'profileImageUrl': '',
          'phoneVerified': false,
          'photoUrl': '',
          'status': 'active',
          'accountStatus': {
            'isActive': true,
            'isVerified': false,
            'isSuspended': false,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }

      if (!driverSnap.exists) {
        debugPrint('[driver-profile-created] uid=$uid');
        tx.set(driverRef, {
          'uid': uid,
          'authUid': uid,
          'userId': uid,
          'driverId': uid,
          'role': 'driver',
          'driverType': 'individual',
          'fleetId': null,
          'fleetOwnerId': null,
          'fleetName': null,
          'createdBy': 'self',
          'credentialIssuedBy': 'self',
          'mustChangePassword': false,
          'firstLoginCompleted': true,
          'fullName': fullName.trim(),
          'phoneNumber': phoneNumber.trim(),
          'email': email.trim().toLowerCase(),
          'profileImageUrl': '',
          'profilePhotoPath': null,
          'vehicleType': '',
          'vehiclePlateNumber': '',
          'vehicleColor': '',
          'vehicleId': '',
          'defaultVehicleId': null,
          'vehicleSummary': <String, dynamic>{},
          'verificationStatus': 'notStarted',
          'onboardingStep': 'profile_created',
          'onboardingStatus': 'in_progress',
          'onboardingComplete': false,
          'accountStatus': 'pending',
          // Phase 6 profile-listing fix (docs/platform/phase-6/PROFILE_LISTING_ROOT_CAUSE.md,
          // root cause B): node-api's admin dashboards filter/read `applicationStatus`
          // (uppercase PENDING/APPROVED/REJECTED) as the canonical approval-state field - this
          // direct-Firestore seed never wrote it at all, so a driver was invisible to any
          // applicationStatus-based listing until (and unless) they reached the region-selection
          // step, which calls POST /api/drivers/apply. Written additively here so a driver is
          // listable from the moment they sign up, before that step. node-api's applyAsDriver
          // still owns backfilling/normalizing this field once the client does call it - this
          // write is a safety net, not a second source of truth.
          'applicationStatus': 'PENDING',
          'canGoOnline': false,
          'status': 'offline',
          'isOnline': false,
          'isAvailable': false,
          'canReceiveRides': false,
          'commissionWalletStatus': 'empty',
          'commissionWalletId': uid,
          'commissionWalletOwnerType': 'driver',
          'payoutOwner': 'driver',
          'payoutAccountId': null,
          'currentRideId': null,
          'currentRideStatus': null,
          'vehicleModel': '',
          'numberOfSeats': 0,
          'cityRegion': cityRegion.trim(),
          // Collected on the signup screen itself (not left empty until the later
          // profile-setup step) - a driver who signed up but never finished
          // profile setup previously had no regionId at all, invisible to every
          // regional admin's driver list until they came back to complete it.
          'regionId': normalizeRegionId(cityRegion),
          'vehicleStatus': 'pending',
          'documentsValid': false,
          'lockedFields': <String>[],
          'rating': 0,
          'totalTrips': 0,
          'totalEarnings': 0,
          'walletBalance': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        });
      } else if (driverSnap.data()?['authUid'] == null) {
        tx.update(driverRef, {
          'authUid': uid,
          'driverId': driverSnap.data()?['driverId'] ?? uid,
          'driverType': driverSnap.data()?['driverType'] ?? 'individual',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!verificationSnap.exists) {
        debugPrint('[driver-verification-doc-created] uid=$uid');
        tx.set(verificationRef, {
          'driverId': uid,
          'status': 'notStarted',
          'submittedAt': null,
          'reviewedAt': null,
          'reviewedBy': null,
          'rejectionReason': null,
          'resubmissionCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> recordLogin(String uid, {String? driverId}) async {
    if (!FirebaseConfig.isAvailable) return;
    try {
      final batch = _db.batch();
      batch.set(
        _db.collection(FirestoreCollections.users).doc(uid),
        {
          'lastLoginAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(_driverRef(driverId ?? uid), {
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
    } catch (e) {
      // Non-critical timestamp update — never blocks login.
      debugPrint('recordLogin: non-fatal error — $e');
    }
  }

  Future<void> ensureDriverUserRecord({
    required String authUid,
    required String fullName,
    required String phoneNumber,
    required String email,
  }) async {
    if (!FirebaseConfig.isAvailable) return;
    await _db.collection(FirestoreCollections.users).doc(authUid).set({
      'uid': authUid,
      'role': 'driver',
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'email': email.trim().toLowerCase(),
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markPasswordChanged(String uid) async {
    if (!FirebaseConfig.isAvailable) return;
    await _driverRef(uid).set({
      'mustChangePassword': false,
      'firstLoginCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveProfileSetup({
    required String uid,
    required String fullName,
    required String phoneNumber,
    required String email,
    required String vehicleType,
    required String vehicleModel,
    required String vehiclePlateNumber,
    required String vehicleColor,
    required int numberOfSeats,
    required String cityRegion,
    required String payoutProvider,
    required String payoutAccountName,
    required String payoutAccountNumber,
  }) async {
    if (!FirebaseConfig.isAvailable) return;

    // Keep this client-side batch limited to documents and fields the driver
    // is explicitly allowed to update. `payout_accounts` and
    // `driver_public_profiles` are retired client-era collections; they have
    // no canonical Firestore write rule and made the *whole* profile batch
    // fail with permission-denied. Until the wallet-payout API is deployed,
    // payout details live in the owner's private users/{uid} profile record,
    // which riders cannot read.
    final batch = _db.batch();
    batch.set(_db.collection(FirestoreCollections.users).doc(uid), {
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'email': email.trim().toLowerCase(),
      'role': 'driver',
      'driverPayoutMethod': {
        'provider': _normalizePayoutProvider(payoutProvider),
        'accountName': payoutAccountName.trim(),
        'accountNumber': payoutAccountNumber.trim(),
        'countryCode': '+237',
        'phoneNumber': _normalizePayoutPhone(payoutAccountNumber),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_driverRef(uid), {
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'email': email.trim().toLowerCase(),
      'vehicleType': vehicleType.toLowerCase(),
      'vehicleModel': vehicleModel.trim(),
      'vehiclePlateNumber': vehiclePlateNumber.trim().toUpperCase(),
      'vehicleColor': vehicleColor,
      'numberOfSeats': numberOfSeats,
      'cityRegion': cityRegion.trim(),
      // The dashboards and node-api's own region-scoping key off `regionId`
      // (canonical, normalized) - `cityRegion` alone is whatever free text the
      // driver typed and was never recognized by either, which is why drivers
      // stopped showing up in the Regional Admin's per-region counts.
      'regionId': normalizeRegionId(cityRegion),
      'vehicleSummary': {
        'type': vehicleType.toLowerCase(),
        'model': vehicleModel.trim(),
        'plateNumber': vehiclePlateNumber.trim().toUpperCase(),
        'color': vehicleColor,
        'seats': numberOfSeats,
      },
      // verificationStatus/status/canGoOnline/canReceiveRides are deliberately NOT written
      // here - they're in firestore.rules' driverProtectedFields() allow-list, settable only
      // by node-api/admin. seedDriverProfile (called right before this, on the same screen
      // submit) already creates them at 'notStarted'/'offline'/false/false; writing
      // 'inProgress' for verificationStatus here changed the value on an UPDATE (the doc now
      // exists from that same seed call), which doesNotModify(driverProtectedFields())
      // rejects outright - every profile-setup save failed with permission-denied
      // ("We could not save your driver profile"), reproduced live on a physical device.
      // Also would have silently forced an already-approved driver back to
      // offline/unable-to-go-online just by editing their profile, had it ever succeeded.
      'onboardingStep': 'national_id',
      'onboardingStatus': 'in_progress',
      'onboardingComplete': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<Map<String, dynamic>?> getDefaultPayoutAccount(String uid) async {
    if (!FirebaseConfig.isAvailable || uid.trim().isEmpty) return null;
    final snapshot = await _db
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();
    final payout = snapshot.data()?['driverPayoutMethod'];
    return payout is Map<String, dynamic> ? payout : null;
  }

  String _normalizePayoutProvider(String value) {
    return switch (value.trim().toLowerCase()) {
      'orange money' || 'orange_money' => 'orange_money',
      'bank' => 'bank',
      'payunit' => 'payunit',
      _ => 'mtn_momo',
    };
  }

  String _normalizePayoutPhone(String value) {
    final compact = value.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (compact.startsWith('+237')) return compact.substring(4);
    return compact.replaceAll(RegExp(r'\D'), '');
  }

  Future<void> setOnline({required String uid, required bool isOnline}) async {
    if (!FirebaseConfig.isAvailable) return;

    // isOnline/status/canGoOnline/canReceiveRides are all in firestore.rules'
    // driverProtectedFields() - a driver changing their own online/offline status is exactly
    // the kind of write those rules exist to block from an unvalidated direct client write (a
    // modified client could otherwise flip itself online regardless of KYC/approval state).
    // Reproduced live on a physical device: the transaction below denied every real toggle
    // attempt with permission-denied the moment status actually changed value, which - by
    // definition - is every attempt that isn't a no-op. The checks below stay as fast,
    // friendly, client-side fail-fast messages; the actual state change now goes through
    // node-api's PATCH /drivers/me/online (driver.service.js#toggleOnline), which re-validates
    // the exact same eligibility server-side (via the Admin SDK, which the rules above don't
    // apply to) and is the authoritative write.
    final ref = _driverRef(uid);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null) throw StateError('Driver profile was not found.');

    // accountStatus is checked via isAccountStatusActive (not a literal 'active' match) plus the
    // real node-api `status` field as a second signal (mirrors node-api's own
    // isAccountActive()/computeOnlineEligibility dual check) - this platform has approved real
    // drivers with accountStatus: 'approved' (an equally-valid alias, not just 'active'), and the
    // literal-match version of this check permanently blocked every one of them from ever going
    // online, no matter what else about their account was fixed. Reproduced live against a real,
    // fully-approved production driver account.
    final accountIsActive =
        isAccountStatusActive(data['accountStatus']?.toString()) ||
        data['status']?.toString().toUpperCase() == 'ACTIVE';
    // canGoOnline is deliberately NOT checked here (or anywhere client-side) as a precondition:
    // it's a server-*computed* cache field node-api's toggleOnline writes as an OUTPUT of a
    // successful eligibility check, not an input a driver must already satisfy - approve()
    // separately sets canReceiveRides (the real, admin-owned "may this driver operate at all"
    // flag) at approval time, but canGoOnline itself only ever becomes true the first time a
    // driver successfully goes online. Requiring it to already be true before attempting that
    // exact call was a permanent deadlock for any driver who had never gone online yet, or whose
    // account was approved before this field was introduced (both true for a real production
    // driver this was reproduced against). node-api's toggleOnline recomputes eligibility fresh
    // on every attempt regardless of this stored value - it is the sole authority.
    if (isOnline &&
        (data['verificationStatus'] != 'approved' ||
            data['canReceiveRides'] != true ||
            !accountIsActive)) {
      throw StateError(
        'Your driver account must be approved before going online.',
      );
    }
    if (isOnline && data['currentRideId'] != null) {
      throw StateError('Complete active trip first.');
    }
    // Commission-wallet eligibility is already checked upstream, before this method is ever
    // called (driver_profile_service.dart#_goOnlineBlockReason ->
    // CommissionWalletService.evaluateGoOnline, which reads the real node-api commission-wallet
    // summary endpoint) - not duplicated here. This used to re-check by reading
    // `commission_wallets/{walletId}` directly from Firestore, but that collection has no rule
    // in the deployed firestore.rules at all (only a stale copy in this app's own checked-in
    // reference rules file ever had one) - every real go-online attempt threw an uncaught
    // FirebaseException(permission-denied) right here, before the request even reached node-api.
    // Reproduced live on a physical device.

    // Part 4: fleet-linked drivers cannot go online without an active vehicle assignment.
    // Independent (non-fleet) drivers are exempt - matches node-api's
    // driver.service.js#toggleOnline, which performs the authoritative version of this same
    // gate server-side right before actually writing the new status.
    final fleetId = data['currentFleetId'] ?? data['fleetId'];
    if (isOnline && fleetId is String && fleetId.isNotEmpty) {
      final fleetSnapshot = await _db
          .collection(FirestoreCollections.fleets)
          .doc(fleetId)
          .get();
      final fleet = fleetSnapshot.data();
      final fleetStatus = (fleet?['status'] ?? fleet?['approvalStatus'] ?? '')
          .toString()
          .toLowerCase();
      if (fleetStatus != 'approved') {
        throw StateError(
          'Fleet Temporarily Suspended. You cannot go online until your fleet is restored.',
        );
      }
    }
    final currentVehicleId = data['currentVehicleId'];
    if (isOnline &&
        fleetId is String &&
        fleetId.isNotEmpty &&
        (currentVehicleId == null ||
            (currentVehicleId is String && currentVehicleId.isEmpty))) {
      throw StateError(
        'No vehicle has been assigned to your account. Please contact your Fleet Owner.',
      );
    }

    try {
      await ApiClient.instance.patch(
        '/api/drivers/me/online',
        body: {'isOnline': isOnline},
      );
    } on ApiException catch (error) {
      throw StateError(error.message);
    }
  }

  Future<void> setOffline(String uid) async {
    if (!FirebaseConfig.isAvailable) return;
    // Same fix as setOnline() above - isOnline/status are driverProtectedFields(), so this
    // must go through node-api rather than writing them directly. Called during sign-out
    // (before the ID token is invalidated) and from the dashboard's online toggle.
    try {
      await ApiClient.instance.patch(
        '/api/drivers/me/online',
        body: {'isOnline': false},
      );
    } on ApiException catch (error) {
      debugPrint('[driver-set-offline-failed] uid=$uid error=${error.message}');
    }
  }

  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phoneNumber,
    required String email,
  }) async {
    if (!FirebaseConfig.isAvailable) return;
    final batch = _db.batch();
    batch.set(_db.collection(FirestoreCollections.users).doc(uid), {
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'email': email.trim().toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_driverRef(uid), {
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'email': email.trim().toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> updateAvatarUrl(String uid, String avatarUrl) async {
    if (!FirebaseConfig.isAvailable) return;
    // profileImageUrl is a plain, unrestricted field (not in firestore.rules'
    // driverProtectedFields()) - safe to write directly, same as updateProfile above.
    await _driverRef(uid).set({
      'profileImageUrl': avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateDeviceToken(String uid, String token) async {
    if (!FirebaseConfig.isAvailable || token.isEmpty) return;
    await _driverRef(uid).set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fleet-linked drivers only: reads the fleet's public profile straight off
  /// `fleets/{fleetId}` (node-api's fleet.service.js is the sole writer of
  /// this document — this app only ever reads it). Powers the Driver
  /// Identification requirement (Fleet Name/Company Name/Logo/Status) and
  /// the Profile screen's Fleet Information section.
  Future<FleetInfo?> getFleetInfo(String fleetId) async {
    if (fleetId.trim().isEmpty || !FirebaseConfig.isAvailable) return null;
    final snapshot = await _db.collection('fleets').doc(fleetId).get();
    final data = snapshot.data();
    if (data == null) return null;
    return FleetInfo.fromMap(data, snapshot.id);
  }

  Stream<FleetInfo?> watchFleetInfo(String fleetId) {
    if (fleetId.trim().isEmpty || !FirebaseConfig.isAvailable) {
      return Stream<FleetInfo?>.value(null);
    }
    return _db
        .collection(FirestoreCollections.fleets)
        .doc(fleetId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return data == null ? null : FleetInfo.fromMap(data, snapshot.id);
        });
  }
}
