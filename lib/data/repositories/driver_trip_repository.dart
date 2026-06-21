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
}
