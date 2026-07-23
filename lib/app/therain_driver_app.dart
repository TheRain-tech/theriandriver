import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../config/env_config.dart';
import '../router/app_routes.dart';
import '../router/route_names.dart';
import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class TheRainDriverApp extends StatefulWidget {
  const TheRainDriverApp({super.key, this.previewMode});

  final bool? previewMode;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<TheRainDriverApp> createState() => _TheRainDriverAppState();
}

class _TheRainDriverAppState extends State<TheRainDriverApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AppLockService.instance.requireAuthOnAppResume();
      return;
    }
    if (state != AppLifecycleState.resumed ||
        AuthService.instance.currentUserId == null ||
        !AppLockService.instance.shouldLockNow()) {
      return;
    }

    final navigator = TheRainDriverApp.navigatorKey.currentState;
    final context = TheRainDriverApp.navigatorKey.currentContext;
    final currentRoute =
        context == null ? null : ModalRoute.of(context)?.settings.name;
    if (navigator == null || currentRoute == RouteNames.appLock) return;

    AppLockService.instance.markLocked();
    AppLockService.instance.setPendingRoute(
      currentRoute ?? RouteNames.dashboard,
    );
    navigator.pushNamed(RouteNames.appLock);
  }

  @override
  Widget build(BuildContext context) {
    EnvConfig.setDebugPreviewOverride(widget.previewMode);
    final isPreview =
        kDebugMode && (widget.previewMode ?? EnvConfig.previewMode);
    return MaterialApp(
      title: 'TheRain Driver',
      navigatorKey: TheRainDriverApp.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fr')],
      initialRoute: isPreview ? RouteNames.dashboard : RouteNames.startup,
      onGenerateRoute: (settings) =>
          AppRoutes.onGenerateRoute(settings, previewMode: isPreview),
    );
  }
}
