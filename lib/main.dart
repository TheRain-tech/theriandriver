import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/therain_driver_app.dart';
import 'config/firebase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(isOptional: true);
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
