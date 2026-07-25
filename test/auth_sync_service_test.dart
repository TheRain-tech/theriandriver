import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/config/firebase_config.dart';
import 'package:theraindriver/services/auth_sync_service.dart';

/// AuthSyncService never touches the network unless FirebaseConfig.isAvailable is true, and that
/// flag is only ever set by a real, successful FirebaseConfig.initialize() call - which never
/// runs in `flutter test` (nothing here calls main() or initializes Firebase). That makes this
/// whole suite hermetic by construction: every call below exercises the real "Firebase not
/// configured yet" code path, proving it fails safely (null/false, never an exception, never a
/// hang) rather than attempting a live HTTP request with no token to attach.
void main() {
  test('FirebaseConfig.isAvailable is false by default under flutter test', () {
    expect(FirebaseConfig.isAvailable, isFalse);
  });

  test(
    'syncSession returns false without touching the network when Firebase is unavailable',
    () async {
      final result = await AuthSyncService.instance.syncSession(
        displayName: 'Test Driver',
      );
      expect(result, isFalse);
    },
  );

  test(
    'fetchMyDriverProfile returns null without touching the network when Firebase is unavailable',
    () async {
      final result = await AuthSyncService.instance.fetchMyDriverProfile();
      expect(result, isNull);
    },
  );

  test(
    'createDriverApplication returns null without touching the network when Firebase is unavailable',
    () async {
      final result = await AuthSyncService.instance.createDriverApplication(
        regionId: 'littoral',
      );
      expect(result, isNull);
    },
  );

  test(
    'saveOnboardingStep (Phase 5) returns null without touching the network when Firebase is unavailable',
    () async {
      final result = await AuthSyncService.instance.saveOnboardingStep(
        'affiliation',
        {'affiliationType': 'fleet'},
      );
      expect(result, isNull);
    },
  );
}
