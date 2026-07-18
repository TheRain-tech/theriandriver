import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/data/repositories/fleet_membership_repository.dart';
import 'package:theraindriver/services/api_client.dart';

/// Same hermetic-by-construction reasoning as auth_sync_service_test.dart for getMyMembership:
/// FirebaseConfig.isAvailable is guaranteed false under `flutter test`, so its guard clause
/// short-circuits before any network call. The other three methods intentionally do NOT guard on
/// FirebaseConfig (a driver reaching the Fleet-join screen is already authenticated) - under test
/// they instead fail fast via ApiClient's own "server address is not configured" check (no
/// EnvConfig.apiBaseUrl under test), which is still a synchronous, network-free failure, never a
/// hang or a real request attempt.
void main() {
  test(
    'getMyMembership returns null without touching the network when Firebase is unavailable',
    () async {
      final result = await FleetMembershipRepository().getMyMembership();
      expect(result, isNull);
    },
  );

  test(
    'requestToJoin fails fast with ApiException (no configured server) rather than hanging or crashing',
    () async {
      await expectLater(
        FleetMembershipRepository().requestToJoin('fleet-1'),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    'acceptInvitation fails fast with ApiException rather than hanging or crashing',
    () async {
      await expectLater(
        FleetMembershipRepository().acceptInvitation('membership-1'),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
