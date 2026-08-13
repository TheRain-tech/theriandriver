import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app/therain_driver_app.dart';
import 'config/firebase_config.dart';
import 'config/production_safety.dart';
import 'firebase_options.dart';

/// Android displays the high-priority notification payload (with the incoming
/// rides channel sound) while the app is backgrounded. Registering this
/// top-level handler also keeps data delivery reliable when the Dart engine is
/// started in the background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await dotenv.load(isOptional: true);
  // Deliberately outside the try/catch below: that block exists to let the app still launch
  // (with a degraded/no-Firebase experience) after a *recoverable* startup failure. Mock fallback
  // reaching a release build is not recoverable - it must stop app startup outright, never fall
  // through to runApp() below.
  ProductionSafety.assertSafeForRelease();
  try {
    await FirebaseConfig.initialize();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'therain_driver.startup',
        context: ErrorDescription('initializing Firebase'),
      ),
    );
    if (kDebugMode) {
      debugPrint('Startup initialization failed: $error');
    }
  }
  runApp(const TheRainDriverApp());
}
