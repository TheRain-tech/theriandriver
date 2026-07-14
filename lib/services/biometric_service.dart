import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Fingerprint / Face ID / Android Biometrics / iOS Face ID/Touch ID.
///
/// This app already keeps the driver signed in via Firebase Auth's own
/// persisted session (the standard mobile Firebase behaviour) — biometrics
/// here is a *local re-entry gate* on top of that existing session, not a
/// replacement for it: the password itself is never stored, and nothing but
/// an opaque "biometrics enabled for this uid, on this device" flag is
/// persisted, in platform secure storage (Android Keystore / iOS Keychain
/// via flutter_secure_storage), so enrollment is strictly per-device and
/// never transfers to a new device (reinstalling/switching devices starts
/// with biometrics disabled again).
class BiometricService {
  BiometricService._();

  static final instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _enabledKeyPrefix = 'biometric_enabled_';
  static const _lastUidKey = 'biometric_last_uid';

  Future<bool> get isDeviceSupported async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (error) {
      debugPrint('[biometric] support check failed: $error');
      return false;
    }
  }

  Future<bool> isEnabledForUid(String uid) async {
    final value = await _storage.read(key: '$_enabledKeyPrefix$uid');
    return value == 'true';
  }

  Future<void> setEnabled(String uid, bool enabled) async {
    if (enabled) {
      await _storage.write(key: '$_enabledKeyPrefix$uid', value: 'true');
      await _storage.write(key: _lastUidKey, value: uid);
    } else {
      await _storage.delete(key: '$_enabledKeyPrefix$uid');
    }
  }

  /// Per-device only: never set by anything except a successful local
  /// enable/login on *this* device, and never synced anywhere.
  Future<String?> get lastUid => _storage.read(key: _lastUidKey);

  /// Clears the "last signed-in uid" pointer (called on sign-out) so the
  /// biometric lock screen isn't offered for an account nobody is signed
  /// into anymore. Per-uid enablement flags are intentionally left in place
  /// so re-signing-in with the same account on this device doesn't force
  /// the user to re-enable biometrics.
  Future<void> forgetLastUid() => _storage.delete(key: _lastUidKey);

  /// Triggers the platform biometric prompt. Returns false (never throws)
  /// on cancel/failure/lockout so callers can always fall back to a
  /// password — biometric failure must never be a permanent lockout.
  Future<bool> authenticate({String reason = 'Verify your identity'}) async {
    try {
      // local_auth 3.x flattened the old options: AuthenticationOptions(...) parameter into
      // named parameters directly on authenticate() (stickyAuth was renamed
      // persistAcrossBackgrounding; useErrorDialogs is legacy and no longer settable - 3.x
      // always treats it as false internally).
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (error) {
      debugPrint('[biometric] authenticate failed: $error');
      return false;
    }
  }
}
