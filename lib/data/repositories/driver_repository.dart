import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../config/firebase_config.dart';
import '../../core/region/region_normalizer.dart';
import '../../firebase/firestore_collections.dart';
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

    return _db
        .collection(FirestoreCollections.drivers)
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return DriverProfile.fromMap(doc.data(), doc.id);
      }
      final direct = await _driverRef(uid).get();
      return _profileFromSnapshot(direct);
    });
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
  }) async {
    if (!FirebaseConfig.isAvailable) return;

    final userRef = _db.collection(FirestoreCollections.users).doc(uid);
    final driverRef = _driverRef(uid);
    final verificationRef =
        _db.collection(FirestoreCollections.driverVerifications).doc(uid);

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
          'cityRegion': '',
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
      batch.set(
          _driverRef(driverId ?? uid),
          {
            'lastSeenAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
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

    final payoutAccountId = '$uid-default';
    final payoutRef = _db
        .collection(FirestoreCollections.payoutAccounts)
        .doc(payoutAccountId);
    // This screen can be saved more than once per signup (profile setup,
    // then again on final review submit, plus any "edit" round-trips). The
    // payout_accounts update rule intentionally excludes createdAt from its
    // allowed keys, so re-sending a fresh serverTimestamp() here on repeat
    // saves would flip createdAt's value and get the whole batch rejected
    // with permission-denied. Only stamp createdAt the first time the doc
    // is created.
    final payoutExists = (await payoutRef.get()).exists;

    final batch = _db.batch();
    batch.set(
        _db.collection(FirestoreCollections.users).doc(uid),
        {
          'fullName': fullName.trim(),
          'phoneNumber': phoneNumber.trim(),
          'email': email.trim().toLowerCase(),
          'role': 'driver',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.set(
        _driverRef(uid),
        {
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
          'verificationStatus': 'inProgress',
          'onboardingStep': 'national_id',
          'onboardingStatus': 'in_progress',
          'onboardingComplete': false,
          'payoutOwner': 'driver',
          'payoutAccountId': payoutAccountId,
          'canReceiveRides': false,
          'canGoOnline': false,
          'isOnline': false,
          'status': 'offline',
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.set(
        payoutRef,
        {
          'accountId': payoutAccountId,
          'ownerType': 'driver',
          'ownerId': uid,
          'provider': _normalizePayoutProvider(payoutProvider),
          'accountName': payoutAccountName.trim(),
          'accountNumber': payoutAccountNumber.trim(),
          'countryCode': '+237',
          'phoneNumber': _normalizePayoutPhone(payoutAccountNumber),
          'status': 'pending_verification',
          'isDefault': true,
          if (!payoutExists) 'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.set(
      _db.collection(FirestoreCollections.driverPublicProfiles).doc(uid),
      {
        'driverId': uid,
        'fullName': fullName.trim(),
        'rating': 0,
        'totalTrips': 0,
        'vehicleType': vehicleType.toLowerCase(),
        'vehicleModel': vehicleModel.trim(),
        'vehicleColor': vehicleColor,
        'driverType': 'individual',
        'fleetName': null,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<Map<String, dynamic>?> getDefaultPayoutAccount(String uid) async {
    if (!FirebaseConfig.isAvailable) return null;
    final snapshot = await _db
        .collection(FirestoreCollections.payoutAccounts)
        .doc('$uid-default')
        .get();
    return snapshot.data();
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

    await _db.runTransaction((transaction) async {
      final ref = _driverRef(uid);
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) throw StateError('Driver profile was not found.');

      if (isOnline &&
          (data['verificationStatus'] != 'approved' ||
              data['canReceiveRides'] != true ||
              data['canGoOnline'] != true ||
              data['accountStatus'] != 'active')) {
        throw StateError(
          'Your driver account must be approved before going online.',
        );
      }
      if (isOnline && data['currentRideId'] != null) {
        throw StateError('Complete active trip first.');
      }
      if (isOnline) {
        final ownerType =
            data['commissionWalletOwnerType']?.toString() ?? 'driver';
        final ownerId =
            ownerType == 'fleet' ? data['fleetId']?.toString() : uid;
        final walletId = data['commissionWalletId']?.toString() ??
            '$ownerType-${ownerId ?? uid}';
        final walletSnap = await transaction.get(
          _db.collection(FirestoreCollections.commissionWallets).doc(walletId),
        );
        final wallet = walletSnap.data();
        final balance = (wallet?['balance'] as num?)?.toDouble() ?? 0;
        final minimum =
            (wallet?['minimumRequiredBalance'] as num?)?.toDouble() ?? 1;
        final walletStatus = wallet?['status']?.toString() ?? 'empty';
        if (wallet == null ||
            walletStatus == 'blocked' ||
            walletStatus == 'empty' ||
            balance < minimum) {
          throw StateError('Top up your commission balance to receive rides.');
        }
      }

      // Part 4: fleet-linked drivers cannot go online without an active vehicle assignment.
      // Independent (non-fleet) drivers are exempt - matches node-api's
      // driver.service.js#toggleOnline, which is the REST-side version of this same gate for
      // any caller that goes through the API instead of this direct Firestore transaction.
      final fleetId = data['currentFleetId'] ?? data['fleetId'];
      if (isOnline && fleetId is String && fleetId.isNotEmpty) {
        final fleetSnapshot = await transaction.get(
          _db.collection(FirestoreCollections.fleets).doc(fleetId),
        );
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

      transaction.update(ref, {
        'isOnline': isOnline,
        'status': isOnline ? 'online' : 'offline',
        'isAvailable': isOnline,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setOffline(String uid) async {
    if (!FirebaseConfig.isAvailable) return;
    await _driverRef(uid).set({
      'isOnline': false,
      'status': 'offline',
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phoneNumber,
    required String email,
  }) async {
    if (!FirebaseConfig.isAvailable) return;
    final batch = _db.batch();
    batch.set(
        _db.collection(FirestoreCollections.users).doc(uid),
        {
          'fullName': fullName.trim(),
          'phoneNumber': phoneNumber.trim(),
          'email': email.trim().toLowerCase(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.set(
        _driverRef(uid),
        {
          'fullName': fullName.trim(),
          'phoneNumber': phoneNumber.trim(),
          'email': email.trim().toLowerCase(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
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
