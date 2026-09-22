import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/core/localization/driver_copy.dart';
import 'package:theraindriver/core/utils/password_policy.dart';

// Every password-creation screen in this app (claim_invitation_screen.dart, signup_screen.dart,
// change_password_screen.dart) previously only checked length, as low as 6 characters in
// change_password_screen.dart - letting straight-through weak passwords like "123456" or
// "12345678" pass. validatePasswordStrength is the one shared rule all three now use.
void main() {
  // DriverCopy.current is English by default in a test binding (no locale/preference set).
  final en = DriverCopy.current;

  test('rejects empty', () {
    expect(validatePasswordStrength('', en), isNotNull);
    expect(validatePasswordStrength(null, en), isNotNull);
  });

  test('rejects purely numeric passwords like "123456" and "12345678"', () {
    expect(validatePasswordStrength('123456', en), isNotNull);
    expect(validatePasswordStrength('12345678', en), isNotNull);
    expect(validatePasswordStrength('00000000', en), isNotNull);
  });

  test('rejects purely alphabetic dictionary-word passwords', () {
    expect(validatePasswordStrength('password', en), isNotNull);
    expect(validatePasswordStrength('iloveyou', en), isNotNull);
  });

  test('rejects a password under 8 characters even with letters and digits', () {
    expect(validatePasswordStrength('ab1234', en), isNotNull);
  });

  test('accepts a password with at least 8 characters, a letter and a digit', () {
    expect(validatePasswordStrength('driver123', en), isNull);
    expect(validatePasswordStrength('Passw0rd', en), isNull);
  });
}
