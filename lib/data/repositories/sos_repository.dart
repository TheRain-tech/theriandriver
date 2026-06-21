import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/firebase_config.dart';
import '../../firebase/firestore_collections.dart';
import '../../services/auth_service.dart';
import '../../services/driver_profile_service.dart';
import '../../services/location_service.dart';

class SosRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> sendSosAlert() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in before sending an SOS alert.');
    final location =
        LocationService.instance.currentLocation.value ??
        await LocationService.instance.getCurrentLocation();
    final user = AuthService.instance.currentUser;
    final currentRideId = DriverProfileService.instance.profile.value.currentRideId;

    if (!FirebaseConfig.isAvailable) {
      return;
    }

    final alertRef = _db.collection(FirestoreCollections.sosAlerts).doc();
    await alertRef.set({
      'alertId': alertRef.id,
      'driverId': uid,
      'userId': uid,
      'userName': user?.displayName ?? 'Driver',
      'userPhone': user?.phoneNumber ?? '',
      'currentRideId': currentRideId,
      'latitude': location.lat,
      'longitude': location.lng,
      'issueType': 'emergency',
      'message': 'SOS emergency triggered by driver',
      'status': 'open',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
