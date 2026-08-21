import 'api_client.dart';

/// Driver-side counterpart to therian's RiderRideApiClient (Phase 1) - calls
/// node-api's ride.routes.js accept/decline/start/complete/cancel endpoints
/// directly instead of RideRepository's direct Firestore transactions
/// against rides/ride_requests. Deliberately paired with Phase 1, per
/// docs/platform/phase-6b/DRIVER_NODE_API_MIGRATION.md: a ride created via
/// node-api needs a driver-side accept that actually calls node-api back to
/// close the loop, rather than writing to the app's own separately-shaped
/// Firestore documents (see ride_repository.dart's rideId/driverSnapshot/
/// selectedRideType shape, which is not the same schema node-api's rides
/// collection uses).
///
/// Reuses the app's existing node-api-pointed ApiClient (see api_client.dart
/// - EnvConfig.apiBaseUrl already targets node-api in this app, unlike
/// therian's rider app which needed a second base URL). Unlike
/// AuthSyncService's best-effort calls, every method here lets ApiException
/// propagate - a failed accept/decline/status change must surface to the
/// driver, never fail silently.
class DriverRideApiClient {
  DriverRideApiClient({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  static final instance = DriverRideApiClient();

  final ApiClient _client;

  /// POST /api/rides/:id/accept - only succeeds if the ride is still
  /// REQUESTED/SEARCHING and this driver is in its candidateDriverIds (or no
  /// candidate list was set). Throws ApiException(statusCode: 409,
  /// code: 'RIDE_UNAVAILABLE') if another driver already took it.
  Future<Map<String, dynamic>> acceptRide(
    String rideId, {
    String? vehicleId,
  }) async {
    final data = await _client.post(
      '/api/rides/$rideId/accept',
      body: {
        if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
      },
    );
    return data as Map<String, dynamic>;
  }

  /// POST /api/rides/:id/decline - removes this driver from the ride's
  /// candidate list; node-api's dispatch loop offers it to the next nearby
  /// driver. Never throws for an already-resolved ride (mirrors node-api's
  /// own idempotent declineRide).
  Future<void> declineRide(String rideId) async {
    await _client.post('/api/rides/$rideId/decline');
  }

  /// POST /api/rides/:id/start - transitions to IN_PROGRESS. Only the
  /// assigned driver may call this (node-api enforces via
  /// assertRideDriverOrAdmin).
  Future<Map<String, dynamic>> startRide(String rideId) async {
    final data = await _client.post('/api/rides/$rideId/start');
    return data as Map<String, dynamic>;
  }

  /// POST /api/rides/:id/complete - transitions to COMPLETED, generates the
  /// receipt, and triggers commission deduction + driver wallet credit
  /// server-side (see ride.service.js#completeRide) - none of that needs to
  /// happen client-side the way it does in RideRepository's
  /// completeRideAndSettleEarnings Cloud Function today.
  Future<Map<String, dynamic>> completeRide(String rideId) async {
    final data = await _client.post('/api/rides/$rideId/complete');
    return data as Map<String, dynamic>;
  }

  /// POST /api/rides/:id/cancel
  Future<Map<String, dynamic>> cancelRide(
    String rideId, {
    String? reason,
  }) async {
    final data = await _client.post(
      '/api/rides/$rideId/cancel',
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return data as Map<String, dynamic>;
  }

  /// GET /api/rides/:id
  Future<Map<String, dynamic>> getRide(String rideId) async {
    final data = await _client.get('/api/rides/$rideId');
    return data as Map<String, dynamic>;
  }

  /// GET /api/rides/mine - node-api filters by driverId when the caller's
  /// role is 'driver', matching this method's name.
  Future<List<Map<String, dynamic>>> myRides({int limit = 50}) async {
    final data = await _client.get('/api/rides/mine', query: {'limit': limit});
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => row.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
  }
}
