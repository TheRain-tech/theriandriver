import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'env_config.dart';

abstract final class FirebaseConfig {
  static bool _isAvailable = false;
  static Object? _initializationError;

  static bool get isAvailable => _isAvailable;
  static Object? get initializationError => _initializationError;
  static bool get useMockFallback =>
      !_isAvailable && kDebugMode && EnvConfig.mockFallbackEnabled;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      _isAvailable = true;
      _initializationError = null;
    } catch (error) {
      _initializationError = error;
      _isAvailable = false;
      if (!kDebugMode || !EnvConfig.mockFallbackEnabled) rethrow;
    }
  }
}
