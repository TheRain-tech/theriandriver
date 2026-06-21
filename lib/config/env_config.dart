import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class EnvConfig {
  static String get firebaseApiKey => _value('FIREBASE_API_KEY');
  static String get firebaseProjectId => _value('FIREBASE_PROJECT_ID');
  static String get firebaseStorageBucket => _value('FIREBASE_STORAGE_BUCKET');
  static String get firebaseMessagingSenderId =>
      _value('FIREBASE_MESSAGING_SENDER_ID');
  static String get firebaseAppId => _value('FIREBASE_APP_ID');
  static String get googleMapsApiKey => _value('GOOGLE_MAPS_API_KEY');
  static String get apiBaseUrl => _value('API_BASE_URL');

  static bool get previewMode => _boolValue('ENABLE_PREVIEW_MODE');
  static bool get mockFallbackEnabled =>
      _boolValue('ENABLE_MOCK_FALLBACK', fallback: true);

  static String _value(String key) {
    if (!dotenv.isInitialized) return '';
    return dotenv.env[key]?.trim() ?? '';
  }

  static bool _boolValue(String key, {bool fallback = false}) {
    final value = _value(key).toLowerCase();
    if (value.isEmpty) return fallback;
    return value == 'true' || value == '1' || value == 'yes';
  }
}
