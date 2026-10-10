import '../../services/api_client.dart';
import '../models/scheduled_ride_offer.dart';

/// Thin REST wrapper over node-api's driver-facing scheduled-ride endpoints
/// (routes/ride.routes.js) - unlike most of this app's ride flow, scheduled rides live only in
/// node-api/Firestore's `scheduled_rides` collection, not the live `rides` dispatch path, so
/// there is no direct-Firestore equivalent the way RideRepository has for `rides`.
class ScheduledRideRepository {
  Future<List<ScheduledRideOffer>> nearbyScheduledRides() async {
    final response = await ApiClient.instance.get('/api/rides/scheduled/nearby');
    final rows = response is List ? response : const [];
    return rows
        .whereType<Map>()
        .map((row) => ScheduledRideOffer.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<void> acceptScheduledRide(String scheduledRideId) {
    return ApiClient.instance.post(
      '/api/rides/scheduled/$scheduledRideId/accept',
    );
  }
}
