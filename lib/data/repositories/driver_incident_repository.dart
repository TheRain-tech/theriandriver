import 'package:firebase_auth/firebase_auth.dart';

import '../../services/api_client.dart';
import '../../services/driver_profile_service.dart';

/// Routes driver safety reports through node-api's real incident-management
/// system (POST /api/incidents -> incident.service.js#createIncident), the
/// same endpoint the rider app's RiderIncidentApiClient already uses and the
/// exact system Trust & Safety / Central Command already reads from (see
/// shared/IncidentManagementCenter.tsx on both admin dashboards) - not the
/// separate support_tickets collection DriverSupportRepository writes to.
///
/// Explicitly passes driverId/fleetId from the driver's own profile so a
/// report is attributable without the backend having to guess: a report
/// with fleetId present is a fleet driver's report, fleetId null is an
/// independent driver's report - the exact distinction Trust & Safety needs
/// to label "Fleet Driver Safety Reports" vs "Independent Driver Safety
/// Reports".
class DriverIncidentRepository {
  Future<String> createSafetyReport({
    required String type,
    required String description,
    String? rideId,
    String? vehicleId,
  }) async {
    final profile = DriverProfileService.instance.profile.value;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? profile.id;
    final data = await ApiClient.instance.post(
      '/api/incidents',
      body: {
        'type': type,
        'description': description,
        'driverId': uid,
        if (profile.fleetId != null && profile.fleetId!.isNotEmpty)
          'fleetId': profile.fleetId,
        if (rideId != null && rideId.isNotEmpty) 'rideId': rideId,
        if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
        if (profile.vehicleId != null && profile.vehicleId!.isNotEmpty)
          'vehicleId': profile.vehicleId,
      },
    );
    final body = data is Map && data['data'] is Map ? data['data'] as Map : data as Map;
    final id = body['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ApiException('The report was sent but no confirmation id came back.');
    }
    return id;
  }
}
