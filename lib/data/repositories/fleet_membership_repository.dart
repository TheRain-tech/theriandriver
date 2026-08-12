import '../../config/firebase_config.dart';
import '../../services/api_client.dart';

/// Phase 5: a driver's own fleetMemberships lifecycle - request to join an approved Fleet,
/// accept/decline a Fleet-sent invitation, and check current status. Mirrors the constructor-
/// injectable pattern already used by [FleetRelationsRepository]/[DriverRevenueRepository] (a
/// fake [ApiClient] can be substituted in tests). All membership state transitions are
/// server-authoritative - this repository never writes membership status directly to Firestore,
/// matching AGENTS.md's binding "approval state must never be client-controlled" rule extended to
/// fleet membership status.
class FleetMembershipRepository {
  FleetMembershipRepository({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// GET /api/drivers/me/membership - the driver's current non-terminal membership (invited,
  /// pending, active, or suspended), or null if they have none.
  Future<Map<String, dynamic>?> getMyMembership() async {
    if (!FirebaseConfig.isAvailable) return null;
    final data = await _client.get('/api/drivers/me/membership');
    return data is Map<String, dynamic> ? data : null;
  }

  /// POST /api/drivers/me/membership/request - request to join an approved Fleet by its ID.
  /// node-api validates the Fleet's existence, active status, and region match server-side; this
  /// call never trusts the fleetId as valid client-side, matching "do not permit typing and
  /// trusting an arbitrary Fleet ID" - the ID is only ever a request, never an assignment.
  Future<Map<String, dynamic>?> requestToJoin(String fleetId) async {
    final data = await _client.post(
      '/api/drivers/me/membership/request',
      body: {'fleetId': fleetId},
    );
    return data is Map<String, dynamic> ? data : null;
  }

  /// POST /api/drivers/me/membership/:id/accept - acknowledge a Fleet-sent invitation
  /// (invited -> pending; final activation still requires TheRain admin KYC-gated approval).
  Future<Map<String, dynamic>?> acceptInvitation(String membershipId) async {
    final data = await _client.post(
      '/api/drivers/me/membership/$membershipId/accept',
      body: const {},
    );
    return data is Map<String, dynamic> ? data : null;
  }

  /// POST /api/drivers/me/membership/:id/decline - decline a Fleet-sent invitation. Terminal.
  Future<Map<String, dynamic>?> declineInvitation(
    String membershipId, {
    String? reason,
  }) async {
    final data = await _client.post(
      '/api/drivers/me/membership/$membershipId/decline',
      body: {'reason': ?reason},
    );
    return data is Map<String, dynamic> ? data : null;
  }

  /// POST /api/fleet-invitations/claim - public (no session yet), for a brand-new driver who
  /// received a one-time invitation code from a Fleet Owner. Creates the Firebase Auth user and
  /// the drivers/{uid} doc server-side, pre-linked to the inviting Fleet (fleetId/regionId) and
  /// starting at applicationStatus PENDING - the driver never types or picks a Fleet themselves.
  /// Returns the new uid, the created driver record (including its email, needed to sign in
  /// immediately after), and the now-accepted membership. Throws [ApiException] on an invalid,
  /// already-used, or expired token (see fleetMembership.service.js#claimFleetInvitation).
  Future<Map<String, dynamic>> claimInvitation({
    required String token,
    required String password,
  }) async {
    final data = await _client.post(
      '/api/fleet-invitations/claim',
      body: {'token': token, 'password': password},
    );
    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected response from the server.');
    }
    return data;
  }
}
