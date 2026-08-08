import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/features/shared/widgets/map_preview_card.dart';

void main() {
  test('native mobile platforms always attempt the configured Google map', () {
    expect(supportsNativeGoogleMaps(TargetPlatform.android), isTrue);
    expect(supportsNativeGoogleMaps(TargetPlatform.iOS), isTrue);
  });

  test('desktop platforms use the non-interactive map preview', () {
    expect(supportsNativeGoogleMaps(TargetPlatform.windows), isFalse);
    expect(supportsNativeGoogleMaps(TargetPlatform.linux), isFalse);
    expect(supportsNativeGoogleMaps(TargetPlatform.macOS), isFalse);
  });
}
