import '../localization/driver_copy.dart';

abstract final class Validators {
  static String? required(String? value, [String? label]) {
    if (value == null || value.trim().isEmpty) {
      final l = DriverCopy.current;
      return label == null
          ? l.t('This field is required', 'Ce champ est obligatoire')
          : l.t('$label is required', '$label est obligatoire');
    }
    return null;
  }

  static String? email(String? value) {
    final l = DriverCopy.current;
    if (value == null || value.trim().isEmpty) {
      return l.t('Email is required', 'L\'e-mail est obligatoire');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return l.t(
        'Enter a valid email address',
        'Saisissez une adresse e-mail valide',
      );
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.replaceAll(RegExp(r'\D'), '').length < 9) {
      return DriverCopy.current.t(
        'Enter a valid phone number',
        'Saisissez un numéro de téléphone valide',
      );
    }
    return null;
  }
}

class CameroonIdValidator {
  const CameroonIdValidator({this.allowSpacesAndHyphens = true});

  final bool allowSpacesAndHyphens;

  String normalize(String value) {
    final compact = allowSpacesAndHyphens
        ? value.trim().replaceAll(RegExp(r'[\s-]'), '')
        : value.trim();
    return compact.toUpperCase();
  }

  bool isValid(String value) {
    final normalized = normalize(value);
    // National ID formats in circulation are not reliably limited to one
    // numeric length. Some cards include a `CM` prefix and older/newer cards
    // vary in formatting. The document images are the authoritative evidence,
    // so onboarding should only reject an empty or obviously malformed value.
    return RegExp(r'^[A-Z0-9]{6,20}$').hasMatch(normalized);
  }

  String validationStatus(String value) => isValid(value)
      ? 'format_valid'
      : normalize(value).isEmpty
      ? 'invalid'
      : 'needs_review';

  String? call(String? value) {
    final text = value ?? '';
    if (!isValid(text)) {
      return DriverCopy.current.t(
        'Enter the ID number exactly as printed on your card.',
        'Saisissez le numéro d\'identité exactement comme imprimé sur votre carte.',
      );
    }
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
      return DriverCopy.current.t(
        'Enter a valid Cameroon mobile money number.',
        'Saisissez un numéro Mobile Money camerounais valide.',
      );
    }
    return null;
  }
}
