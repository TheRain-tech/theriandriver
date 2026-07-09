import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class AppLockService {
  AppLockService._();

  static final instance = AppLockService._();

  static const _channel = MethodChannel('therain_driver/security_settings');
  static const Duration resumeLockTimeout = Duration(minutes: 2);

  final LocalAuthentication _localAuth = LocalAuthentication();
  DateTime? _backgroundedAt;
  bool _unlockedSession = false;
  String? _pendingRoute;

  bool get unlockedSession => _unlockedSession;
  String? get pendingRoute => _pendingRoute;

  void setPendingRoute(String route) => _pendingRoute = route;

  String consumePendingRoute({String fallback = '/dashboard'}) {
    final route = _pendingRoute ?? fallback;
    _pendingRoute = null;
    return route;
  }

  Future<bool> isDeviceSecure() async {
    try {
      return _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> canAuthenticate() async {
    try {
      return await _localAuth.isDeviceSupported() ||
          await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateForAccountAccess() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock TheRain Driver to access your account.',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) markUnlockedSession();
      return authenticated;
    } on PlatformException {
      return false;
    }
  }

  void requireAuthOnAppResume() {
    _backgroundedAt = DateTime.now();
  }

  bool shouldLockNow() {
    if (!_unlockedSession) return true;
    final backgroundedAt = _backgroundedAt;
    if (backgroundedAt == null) return false;
    return DateTime.now().difference(backgroundedAt) >= resumeLockTimeout;
  }

  void markUnlockedSession() {
    _unlockedSession = true;
    _backgroundedAt = null;
  }

  void markLocked() {
    _unlockedSession = false;
  }

  Future<void> openSecuritySettings() async {
    try {
      await _channel.invokeMethod<void>('openSecuritySettings');
    } on PlatformException {
      await openAppSettings();
    } on MissingPluginException {
      await openAppSettings();
    }
  }
}
