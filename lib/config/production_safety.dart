import 'package:flutter/foundation.dart';

import 'env_config.dart';

/// Startup guard proving `ENABLE_MOCK_FALLBACK=true` (or preview mode) can never reach a release
/// build. `EnvConfig.mockFallbackEnabled`/`EnvConfig.previewMode` are already individually gated
/// on `kDebugMode`, so this is defense in depth, not the only line of defense: it makes the
/// invariant explicit and self-checking, so a future refactor that accidentally weakens either
/// gate is caught here (a loud startup failure) instead of silently shipping a release build that
/// can authenticate a mock driver.
abstract final class ProductionSafety {
  /// Throws a [StateError] if mock/preview fallback could be active in a release build. Call once
  /// during app startup, before [runApp]. The three `*Override` parameters exist purely for
  /// hermetic testing - `kReleaseMode` itself cannot be toggled at runtime, so tests inject the
  /// scenario they want to verify instead.
  static void assertSafeForRelease({
    bool? isReleaseOverride,
    bool? mockFallbackOverride,
    bool? previewModeOverride,
  }) {
    final isRelease = isReleaseOverride ?? kReleaseMode;
    final mockFallback = mockFallbackOverride ?? EnvConfig.mockFallbackEnabled;
    final previewMode = previewModeOverride ?? EnvConfig.previewMode;

    if (isRelease && (mockFallback || previewMode)) {
      throw StateError(
        'Refusing to start: ENABLE_MOCK_FALLBACK and ENABLE_PREVIEW_MODE must never be enabled '
        'in a release build. This build was compiled with one of them set - fix the release '
        'dart-defines/.env and rebuild. A release build must never be able to authenticate a '
        'mock driver.',
      );
    }
  }
}
