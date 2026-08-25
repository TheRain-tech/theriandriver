import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-only preferences that affect presentation and local ride alerts.
///
/// These values do not grant access or alter a driver's operational status, so
/// they intentionally remain on the device rather than being stored in a
/// driver profile document.
class DriverAppPreferences {
  const DriverAppPreferences({
    required this.themeMode,
    required this.locale,
    required this.rideAlertsEnabled,
  });

  const DriverAppPreferences.defaults()
    : themeMode = ThemeMode.light,
      locale = const Locale('en'),
      rideAlertsEnabled = true;

  final ThemeMode themeMode;
  final Locale locale;
  final bool rideAlertsEnabled;

  DriverAppPreferences copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? rideAlertsEnabled,
  }) => DriverAppPreferences(
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    rideAlertsEnabled: rideAlertsEnabled ?? this.rideAlertsEnabled,
  );
}

class DriverPreferencesService {
  DriverPreferencesService._();

  static final instance = DriverPreferencesService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final ValueNotifier<DriverAppPreferences> preferences = ValueNotifier(
    const DriverAppPreferences.defaults(),
  );

  static const _themeKey = 'driver_theme_mode';
  static const _languageKey = 'driver_language';
  static const _rideAlertsKey = 'driver_ride_alerts_enabled';

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final values = await Future.wait([
        _storage.read(key: _themeKey),
        _storage.read(key: _languageKey),
        _storage.read(key: _rideAlertsKey),
      ]);
      preferences.value = DriverAppPreferences(
        themeMode: _themeFromStoredValue(values[0]),
        locale: values[1]?.toLowerCase() == 'fr'
            ? const Locale('fr')
            : const Locale('en'),
        rideAlertsEnabled: values[2] != 'false',
      );
    } catch (_) {
      // Presentation preferences are optional. A storage failure should never
      // prevent a driver from opening the app or receiving a ride request.
    }
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    _set(preferences.value.copyWith(themeMode: themeMode));
    await _write(_themeKey, themeMode.name);
  }

  Future<void> setLocale(Locale locale) async {
    final normalized = locale.languageCode.toLowerCase() == 'fr'
        ? const Locale('fr')
        : const Locale('en');
    _set(preferences.value.copyWith(locale: normalized));
    await _write(_languageKey, normalized.languageCode);
  }

  Future<void> setRideAlertsEnabled(bool enabled) async {
    _set(preferences.value.copyWith(rideAlertsEnabled: enabled));
    await _write(_rideAlertsKey, enabled.toString());
  }

  void _set(DriverAppPreferences value) {
    preferences.value = value;
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Keep the selected value for this active session if persistence fails.
    }
  }

  ThemeMode _themeFromStoredValue(String? value) => switch (value) {
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => ThemeMode.light,
  };
}
