import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manual language override for the driver app (English/French only, matching
/// MaterialApp's supportedLocales in therain_driver_app.dart), persisted
/// per-device via flutter_secure_storage — this app has no shared_preferences
/// dependency, unlike the Fleet App's AppSettingsController which this mirrors.
class LocaleService {
  LocaleService._();

  static final instance = LocaleService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _localeKey = 'driver_locale_code';
  static const _selectionCompletedKey = 'driver_language_selection_completed';

  final ValueNotifier<Locale?> localeNotifier = ValueNotifier<Locale?>(null);
  bool languageSelectionCompleted = false;

  Future<void> load() async {
    final code = await _storage.read(key: _localeKey);
    if (code == 'en' || code == 'fr') {
      localeNotifier.value = Locale(code!);
    }
    languageSelectionCompleted =
        (await _storage.read(key: _selectionCompletedKey)) == 'true';
  }

  Future<void> completeLanguageSelection(Locale locale) async {
    localeNotifier.value = locale;
    languageSelectionCompleted = true;
    await _storage.write(key: _localeKey, value: locale.languageCode);
    await _storage.write(key: _selectionCompletedKey, value: 'true');
  }
}
