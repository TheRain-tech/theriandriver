import '../localization/driver_copy.dart';

/// The minimum bar every new/changed password in this app must clear. Every screen that lets a
/// driver set a password (claim_invitation_screen.dart, signup_screen.dart,
/// change_password_screen.dart) previously only checked length (as low as 6 characters in
/// change_password_screen.dart), which let a straight-through weak password like "123456" or
/// "12345678" pass. Deliberately not a blocklist to maintain - requiring at least one letter AND
/// one digit rejects every purely-numeric "123456"-style password and every purely-alphabetic
/// dictionary word ("password", "iloveyou") in one simple, explainable rule, without needing an
/// ever-growing list of banned values.
String? validatePasswordStrength(String? value, DriverCopy copy) {
  final password = value ?? '';
  if (password.isEmpty) {
    return copy.t('Password is required', 'Le mot de passe est obligatoire');
  }
  if (password.length < 8) {
    return copy.t(
      'Password must be at least 8 characters',
      'Le mot de passe doit contenir au moins 8 caractères',
    );
  }
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
  final hasDigit = RegExp(r'[0-9]').hasMatch(password);
  if (!hasLetter || !hasDigit) {
    return copy.t(
      'Password must include both letters and numbers',
      'Le mot de passe doit contenir des lettres et des chiffres',
    );
  }
  return null;
}
