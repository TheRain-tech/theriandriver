import 'package:firebase_auth/firebase_auth.dart';

import '../../config/env_config.dart';
import '../../config/firebase_config.dart';
import '../mock/mock_driver_trips.dart';
import '../models/driver_trip.dart';
import 'ride_repository.dart';

class DriverTripRepository {
  DriverTripRepository({RideRepository? rides})
    : _rides = rides ?? RideRepository();

  final RideRepository _rides;

  Future<List<DriverTrip>> getTrips() async {
    final uid = FirebaseConfig.isAvailable
        ? FirebaseAuth.instance.currentUser?.uid
        : null;
    if (uid == null && !EnvConfig.previewMode) return const [];
    return _rides.watchDriverTrips(uid ?? 'preview-driver').first;
  }

  Future<DriverTrip?> getTrip(String id) async {
    if (EnvConfig.previewMode || FirebaseConfig.useMockFallback) {
      return mockDriverTrips.where((trip) => trip.id == id).firstOrNull ??
          mockDriverTrips.firstOrNull;
    }
    return _rides.getRide(id);
  }

  Future<void> submitRiderRating({
    required String rideId,
    required int rating,
  }) async {
    if (EnvConfig.previewMode || FirebaseConfig.useMockFallback) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('You must be signed in to rate a rider.');
    await _rides.submitRiderRating(uid: uid, rideId: rideId, rating: rating);
  }
}
