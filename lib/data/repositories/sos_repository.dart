import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_client.dart';
import '../../services/driver_profile_service.dart';
import '../../services/location_service.dart';

/// Routes the driver SOS button through node-api's real emergency pipeline
/// (POST /sos -> sos.service.js#trigger) instead of the previous direct write
/// to the `sos_alerts` Firestore collection - a known migration-target
/// duplicate of the canonical `sos_incidents` collection (see this repo's
/// AGENTS.md security section), which no admin dashboard or camera-capture
/// logic ever reads. The old write also never included vehicleId, so even a
/// correctly-wired admin view couldn't have resolved this driver's camera.
class SosRepository {
  Future<String> sendSosAlert() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in before sending an SOS alert.');
    final location =
        LocationService.instance.currentLocation.value ??
        await LocationService.instance.getCurrentLocation();
    final profile = DriverProfileService.instance.profile.value;

    final data = await ApiClient.instance.post(
      '/api/sos',
      body: {
        'gps': {
          'lat': location.lat,
          'lng': location.lng,
          'accuracy': location.accuracy,
        },
        if (profile.currentRideId != null && profile.currentRideId!.isNotEmpty)
          'rideId': profile.currentRideId,
        if (profile.vehicleId != null && profile.vehicleId!.isNotEmpty)
          'vehicleId': profile.vehicleId,
        'message': 'SOS emergency triggered by driver',
      },
    );
    final body = data is Map && data['data'] is Map
        ? data['data'] as Map
        : data as Map;
    final id = body['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ApiException(
        'The alert was sent but no confirmation id came back.',
      );
    }
    return id;
  }
}
