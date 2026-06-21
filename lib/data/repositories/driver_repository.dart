import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config/firebase_config.dart';
import '../../firebase/firestore_collections.dart';
import '../mock/mock_driver_profile.dart';
import '../models/driver_profile.dart';

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

    final snapshot = await _driverRef(uid).get();
    final data = snapshot.data();
    return data == null ? null : DriverProfile.fromMap(data, snapshot.id);
  }

  Stream<DriverProfile?> watchProfile(String uid) {
    if (FirebaseConfig.useMockFallback) {
      return Stream<DriverProfile?>.value(mockDriverProfile);
    }
    if (!FirebaseConfig.isAvailable) {
      return Stream<DriverProfile?>.value(null);
    }

    return _driverRef(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null ? null : DriverProfile.fromMap(data, snapshot.id);
    });
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
    final batch = _db.batch();

    batch.set(userRef, {
      'uid': uid,
      'role': 'driver',
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'email': email.trim().toLowerCase(),
      'profileImageUrl': '',
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
    }, SetOptions(merge: true));

    batch.set(driverRef, {
      'uid': uid,
      'driverId': uid,
      'role': 'driver',
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
      'accountStatus': 'pending',
      'status': 'offline',
      'isOnline': false,
      'canReceiveRides': false,
      'currentRideId': null,
      'currentRideStatus': null,
      'rating': 0,
      'totalTrips': 0,
      'totalEarnings': 0,
      'walletBalance': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> saveProfileSetup({
    required String uid,
    required String fullName,
    required String phoneNumber,
    required String email,
    required String vehicleType,
    required String vehiclePlateNumber,
    required String vehicleColor,
  }) async {
    if (!FirebaseConfig.isAvailable) return;

    final batch = _db.batch();
    batch.set(_db.collection(FirestoreCollections.users).doc(uid), {
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'email': email.trim().toLowerCase(),
      'role': 'driver',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_driverRef(uid), {
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'email': email.trim().toLowerCase(),
      'vehicleType': vehicleType.toLowerCase(),
      'vehiclePlateNumber': vehiclePlateNumber.trim().toUpperCase(),
      'vehicleColor': vehicleColor,
      'vehicleSummary': {
        'type': vehicleType.toLowerCase(),
        'plateNumber': vehiclePlateNumber.trim().toUpperCase(),
        'color': vehicleColor,
      },
      'verificationStatus': 'inProgress',
      'canReceiveRides': false,
      'isOnline': false,
      'status': 'offline',
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
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
              data['canReceiveRides'] != true)) {
        throw StateError(
          'Your driver account must be approved before going online.',
        );
      }

      transaction.update(ref, {
        'isOnline': isOnline,
        'status': isOnline ? 'online' : 'offline',
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

  Future<void> updateDeviceToken(String uid, String token) async {
    if (!FirebaseConfig.isAvailable || token.isEmpty) return;
    await _driverRef(uid).set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
