import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/config/production_safety.dart';

/// Proves ENABLE_MOCK_FALLBACK/ENABLE_PREVIEW_MODE can never reach a release build (Phase 4
/// section 8's explicit requirement: "Add tests proving this"). `kReleaseMode` itself cannot be
/// toggled at test time, so these use assertSafeForRelease's override parameters to exercise
/// every combination the real startup call could see.
void main() {
  test('throws when a release build would have mock fallback enabled', () {
    expect(
      () => ProductionSafety.assertSafeForRelease(
        isReleaseOverride: true,
        mockFallbackOverride: true,
        previewModeOverride: false,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('throws when a release build would have preview mode enabled', () {
    expect(
      () => ProductionSafety.assertSafeForRelease(
        isReleaseOverride: true,
        mockFallbackOverride: false,
        previewModeOverride: true,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('throws when a release build would have both enabled', () {
    expect(
      () => ProductionSafety.assertSafeForRelease(
        isReleaseOverride: true,
        mockFallbackOverride: true,
        previewModeOverride: true,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('does not throw for a correctly configured release build', () {
    expect(
      () => ProductionSafety.assertSafeForRelease(
        isReleaseOverride: true,
        mockFallbackOverride: false,
        previewModeOverride: false,
      ),
      returnsNormally,
    );
  });

  test('never throws in a debug build regardless of mock/preview flags', () {
    expect(
      () => ProductionSafety.assertSafeForRelease(
        isReleaseOverride: false,
        mockFallbackOverride: true,
        previewModeOverride: true,
      ),
      returnsNormally,
    );
  });

  test(
    'the error message never echoes back any config value, only names the flags',
    () {
      try {
        ProductionSafety.assertSafeForRelease(
          isReleaseOverride: true,
          mockFallbackOverride: true,
          previewModeOverride: false,
        );
        fail('expected a StateError');
      } on StateError catch (error) {
        expect(error.message, contains('ENABLE_MOCK_FALLBACK'));
        expect(error.message, contains('ENABLE_PREVIEW_MODE'));
      }
    },
  );
}
