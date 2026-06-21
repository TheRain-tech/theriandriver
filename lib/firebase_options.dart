// Generated from the registered TheRain Driver apps in therain-production.
// Firebase API keys identify the Firebase project; they are not server secrets.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => ios,
      TargetPlatform.windows => web,
      TargetPlatform.linux => throw UnsupportedError(
        'Firebase is not configured for Linux in TheRain Driver.',
      ),
      TargetPlatform.fuchsia => throw UnsupportedError(
        'Firebase is not configured for Fuchsia in TheRain Driver.',
      ),
    };
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyCBHiM8A8yOw8zeu4MFRT-o6MsqqcFKg5I',
    appId: '1:8765794703:web:c53fa24102378217e7c3fa',
    messagingSenderId: '8765794703',
    projectId: 'therain-production',
    authDomain: 'therain-production.firebaseapp.com',
    storageBucket: 'therain-production.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyB6MRrPC_O6uhhE7GtoMEolRH2EQhbD0tk',
    appId: '1:8765794703:android:ac25ebaa59abc10be7c3fa',
    messagingSenderId: '8765794703',
    projectId: 'therain-production',
    storageBucket: 'therain-production.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyC5HIMw3XIheZtDdVujJJVR0aqOzwhdEj0',
    appId: '1:8765794703:ios:e8f63a1ee57cc5abe7c3fa',
    messagingSenderId: '8765794703',
    projectId: 'therain-production',
    storageBucket: 'therain-production.firebasestorage.app',
    iosBundleId: 'com.therain.driver',
  );
}
