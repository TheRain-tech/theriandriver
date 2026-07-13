abstract final class Validators {
  static String? required(String? value, [String label = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.replaceAll(RegExp(r'\D'), '').length < 9) {
      return 'Enter a valid phone number';
    }
    return null;
  }
}

class CameroonIdValidator {
  const CameroonIdValidator({
    this.acceptedDigitLengths = const [9, 10],
    this.allowSpacesAndHyphens = true,
  });

  final List<int> acceptedDigitLengths;
  final bool allowSpacesAndHyphens;

  String normalize(String value) {
    final trimmed = value.trim();
    return allowSpacesAndHyphens
        ? trimmed.replaceAll(RegExp(r'[\s-]'), '')
        : trimmed;
  }

  bool isValid(String value) {
    final normalized = normalize(value);
    return RegExp(r'^\d+$').hasMatch(normalized) &&
        acceptedDigitLengths.contains(normalized.length);
  }

  String validationStatus(String value) => isValid(value)
      ? 'format_valid'
      : normalize(value).isEmpty
      ? 'invalid'
      : 'needs_review';

  String? call(String? value) {
    final text = value ?? '';
    if (!isValid(text)) return 'Enter a valid Cameroon National ID number.';
    return null;
  }
}

class CameroonPhoneNumber {
  const CameroonPhoneNumber._();

  static String? normalize(String value) {
    final compact = value.trim().replaceAll(RegExp(r'[\s-]'), '');
    final digits = compact.startsWith('+237')
        ? compact.substring(4)
        : compact.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\d{9}$').hasMatch(digits)) return null;
    return '+237$digits';
  }

  static String? validateMobileMoney(String? value) {
    if (value == null || normalize(value) == null) {
      return 'Enter a valid Cameroon mobile money number.';
    }
    return null;
  }
}
