import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'env_config.dart';

abstract final class FirebaseConfig {
  static const expectedProjectId = 'therain-production';
  static const functionsRegion = 'africa-south1';

  static bool _isAvailable = false;
  static Object? _initializationError;

  static bool get isAvailable => _isAvailable;
  static Object? get initializationError => _initializationError;
  static bool get useMockFallback =>
      !_isAvailable && kDebugMode && EnvConfig.mockFallbackEnabled;

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final actualProjectId = Firebase.app().options.projectId;
      if (actualProjectId != expectedProjectId) {
        throw StateError(
          'Firebase project mismatch. Expected $expectedProjectId, got '
          '$actualProjectId.',
        );
      }
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      _isAvailable = true;
      _initializationError = null;
      final opts = Firebase.app().options;
      debugPrint('[driver-firebase-config] projectId=${opts.projectId}');
      debugPrint('[driver-firebase-config] appId=${opts.appId}');
      debugPrint(
        '[driver-firebase-config] apiKeyPrefix=${opts.apiKey.substring(0, 8)}…',
      );
    } catch (error) {
      _initializationError = error;
      _isAvailable = false;
      if (!kDebugMode || !EnvConfig.mockFallbackEnabled) rethrow;
    }
  }
}
