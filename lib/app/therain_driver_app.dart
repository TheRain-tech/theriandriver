import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../config/env_config.dart';
import '../router/app_routes.dart';
import '../router/route_names.dart';
import '../theme/app_theme.dart';

class TheRainDriverApp extends StatelessWidget {
  const TheRainDriverApp({super.key, this.previewMode});

  final bool? previewMode;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    EnvConfig.setDebugPreviewOverride(previewMode);
    final isPreview = kDebugMode && (previewMode ?? EnvConfig.previewMode);
    return MaterialApp(
      title: 'TheRain Driver',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: isPreview ? RouteNames.dashboard : RouteNames.startup,
      onGenerateRoute: (settings) =>
          AppRoutes.onGenerateRoute(settings, previewMode: isPreview),
    );
  }
}
