import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../config/firebase_config.dart';
import '../../firebase/firestore_collections.dart';
import '../models/live_location.dart';

class LocationRepository {
  LocationRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  Future<void> updateDriverLocation({
    required String uid,
    required double lat,
    required double lng,
    required double heading,
    required double speed,
    required double accuracy,
    required bool isOnline,
    String? currentRideId,
    bool? isAvailable,
    bool? isOnTrip,
    String? vehicleType,
    List<String>? supportedRideTypes,
  }) async {
    if (!FirebaseConfig.isAvailable) return;
    try {
      await _db
          .collection(FirestoreCollections.driverLiveLocations)
          .doc(uid)
          .set({
            'driverId': uid,
            'lat': lat,
            'lng': lng,
            'latitude': lat,
            'longitude': lng,
            'heading': heading,
            'speed': speed,
            'accuracy': accuracy,
            'isOnline': isOnline,
            'isAvailable': isAvailable ?? (isOnline && currentRideId == null),
            'isOnTrip': isOnTrip ?? (currentRideId != null),
            'vehicleType': vehicleType ?? '',
            'supportedRideTypes':
                supportedRideTypes ??
                (vehicleType != null && vehicleType.isNotEmpty
                    ? [vehicleType]
                    : const <String>[]),
            'currentRideId': currentRideId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      debugPrint('[driver-location-write-success] uid=$uid lat=$lat lng=$lng');
    } catch (e) {
      debugPrint('[driver-location-write-fail] uid=$uid error=$e');
      rethrow;
    }
  }

  Future<void> setDriverOffline(String uid) async {
    if (!FirebaseConfig.isAvailable) return;
    await _db
        .collection(FirestoreCollections.driverLiveLocations)
        .doc(uid)
        .set({
          'driverId': uid,
          'isOnline': false,
          'currentRideId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Stream<LiveLocation?> watchDriverLocation(String uid) {
    if (!FirebaseConfig.isAvailable) return Stream.value(null);
    return _db
        .collection(FirestoreCollections.driverLiveLocations)
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return data == null
              ? null
              : LiveLocation.fromDriverMap(data, snapshot.id);
        });
  }

  Stream<LiveLocation?> watchRiderLocation({
    required String riderId,
    required String rideId,
  }) {
    if (!FirebaseConfig.isAvailable) return Stream.value(null);
    return _db
        .collection(FirestoreCollections.riderLiveLocations)
        .doc(riderId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null || data['currentRideId']?.toString() != rideId) {
            return null;
          }
          return LiveLocation.fromRiderMap(data, snapshot.id);
        });
  }
}
