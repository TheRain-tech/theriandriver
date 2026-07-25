import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

abstract final class EnvConfig {
  static bool? _debugPreviewOverride;

  static String get firebaseApiKey => _value('FIREBASE_API_KEY');
  static String get firebaseProjectId => _value('FIREBASE_PROJECT_ID');
  static String get firebaseStorageBucket => _value('FIREBASE_STORAGE_BUCKET');
  static String get firebaseMessagingSenderId =>
      _value('FIREBASE_MESSAGING_SENDER_ID');
  static String get firebaseAppId => _value('FIREBASE_APP_ID');
  static String get googleMapsApiKey => _value('GOOGLE_MAPS_API_KEY');
  static String get apiBaseUrl => _value('API_BASE_URL');

  static bool get googleSignInEnabled => _boolValue('ENABLE_GOOGLE_SIGN_IN');
  static String get googleServerClientId => _value('GOOGLE_SERVER_CLIENT_ID');

  static bool get previewMode {
    if (!kDebugMode) return false;
    return _debugPreviewOverride ?? _boolValue('ENABLE_PREVIEW_MODE');
  }

  static bool get mockFallbackEnabled =>
      kDebugMode && _boolValue('ENABLE_MOCK_FALLBACK');

  /// Phase 2 (driver-side node-api ride acceptance, see
  /// docs/platform/phase-6b/DRIVER_NODE_API_MIGRATION.md): gates whether
  /// accept/decline/start/complete calls go through node-api's
  /// DriverRideApiClient instead of RideRepository's direct Firestore
  /// transactions. Defaults false - nothing in the app calls the new client
  /// unless this is explicitly turned on, and flipping it is a deliberate
  /// cutover decision paired with Phase 1's USE_NODE_API_BOOKING on the
  /// rider side, not a side effect of adding the client code itself.
  static bool get useNodeApiRideAcceptance =>
      _boolValue('USE_NODE_API_RIDE_ACCEPTANCE');

  static void setDebugPreviewOverride(bool? value) {
    if (!kDebugMode) return;
    _debugPreviewOverride = value;
  }

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
