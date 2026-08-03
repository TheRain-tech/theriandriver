import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'env_config.dart';

abstract final class FirebaseConfig {
  static const expectedProjectId = 'therain-production';
  static const storageBucket = 'therain-production-rider-assets';
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
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } on FirebaseException catch (error) {
          // Android's FirebaseInitProvider can win the startup race between
          // Firebase.apps and initializeApp. Reuse that correctly configured
          // native default app instead of failing the whole release startup.
          if (error.code != 'duplicate-app') rethrow;
          Firebase.app();
        }
      }
      final actualProjectId = Firebase.app().options.projectId;
      if (actualProjectId != expectedProjectId) {
        throw StateError(
          'Firebase project mismatch. Expected $expectedProjectId, got '
          '$actualProjectId.',
        );
      }
      final actualStorageBucket = Firebase.app().options.storageBucket;
      if (actualStorageBucket != storageBucket) {
        throw StateError(
          'Firebase Storage bucket mismatch. Expected $storageBucket, got '
          '$actualStorageBucket.',
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
      debugPrint('[driver-firebase-config] storageBucket=$storageBucket');
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
