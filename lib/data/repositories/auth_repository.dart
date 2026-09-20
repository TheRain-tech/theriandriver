import 'package:firebase_auth/firebase_auth.dart';

import '../../config/firebase_config.dart';
import '../models/auth_user.dart';

class AuthRepository {
  /// [driverTenantId] defaults to the build's configured driver pool
  /// (FirebaseConfig.driverAuthTenantId); tests pass their own. An empty value means "no separate
  /// driver pool" and every call behaves exactly as it did with a single shared pool.
  AuthRepository({FirebaseAuth? auth, String? driverTenantId})
    : _authOverride = auth,
      _driverTenantId = (driverTenantId ?? FirebaseConfig.driverAuthTenantId)
          .trim();

  final FirebaseAuth? _authOverride;
  final String _driverTenantId;
  AuthUser? _mockUser;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  bool get _hasDriverPool => _driverTenantId.isNotEmpty;

  AuthUser? get currentUser {
    if (FirebaseConfig.useMockFallback) return _mockUser;
    if (!FirebaseConfig.isAvailable) return null;
    return _mapUser(_auth.currentUser);
  }

  Stream<AuthUser?> authStateChanges() {
    if (FirebaseConfig.useMockFallback) {
      return Stream<AuthUser?>.value(_mockUser);
    }
    if (!FirebaseConfig.isAvailable) return Stream<AuthUser?>.value(null);
    return _auth.authStateChanges().map(_mapUser);
  }

  /// Sign-in error codes that only mean "this login is not in this pool / wrong password here" -
  /// the only ones that justify trying the other pool. Anything else (too many attempts, network,
  /// disabled account) is real and must not be masked by a second attempt.
  static bool _isCredentialProblem(String code) {
    const codes = {
      'user-not-found',
      'wrong-password',
      'invalid-credential',
      'invalid-login-credentials',
      'invalid-email',
    };
    return codes.contains(code.toLowerCase());
  }

  /// New driver accounts are created in the driver pool, so an email that already belongs to a
  /// rider (in the default pool) does not block it - the rider and driver accounts stay separate,
  /// each with its own password.
  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (FirebaseConfig.useMockFallback) {
      return _mockUser = AuthUser(
        uid: 'mock-driver',
        email: email,
        phoneNumber: '',
        displayName: fullName,
        isMock: true,
      );
    }

    if (_hasDriverPool) _auth.tenantId = _driverTenantId;
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(fullName.trim());
    final user = _mapUser(credential.user);
    if (user == null) throw StateError('Firebase did not return a user.');
    return user;
  }

  /// Tries the driver pool first, then the shared default pool (drivers who registered before
  /// driver logins had their own pool). A login found only in the default pool comes back with
  /// [AuthUser.viaDefaultPool] set, because it may be a rider's account - the caller must confirm
  /// it is really a driver's before treating it as one.
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (FirebaseConfig.useMockFallback) {
      return _mockUser = AuthUser(
        uid: 'mock-driver',
        email: email,
        phoneNumber: '',
        displayName: 'Development Driver',
        isMock: true,
      );
    }

    if (_hasDriverPool) {
      _auth.tenantId = _driverTenantId;
      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return _requireUser(credential.user);
      } on FirebaseAuthException catch (error) {
        if (!_isCredentialProblem(error.code)) rethrow;
      }
      _auth.tenantId = null;
      final legacy = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _requireUser(legacy.user, viaDefaultPool: true);
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _requireUser(credential.user);
  }

  Future<void> signOut() async {
    if (FirebaseConfig.useMockFallback) {
      _mockUser = null;
      return;
    }
    if (FirebaseConfig.isAvailable) {
      await _auth.signOut();
    }
  }

  /// Client-side reset inside the driver pool - only a fallback for when the backend cannot be
  /// reached; AuthService.resetPassword asks the backend, which knows which pool the login is in.
  Future<void> sendPasswordResetEmail(String email) async {
    if (!FirebaseConfig.isAvailable) {
      throw StateError('Firebase Authentication is unavailable.');
    }
    if (_hasDriverPool) _auth.tenantId = _driverTenantId;
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> updateCurrentPassword(String newPassword) async {
    if (FirebaseConfig.useMockFallback) return;
    if (!FirebaseConfig.isAvailable) {
      throw StateError('Firebase Authentication is unavailable.');
    }
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in before changing password.');
    await user.updatePassword(newPassword);
  }

  AuthUser _requireUser(User? user, {bool viaDefaultPool = false}) {
    final mapped = _mapUser(user, viaDefaultPool: viaDefaultPool);
    if (mapped == null) throw StateError('Firebase did not return a user.');
    return mapped;
  }

  AuthUser? _mapUser(User? user, {bool viaDefaultPool = false}) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      phoneNumber: user.phoneNumber ?? '',
      displayName: user.displayName ?? '',
      viaDefaultPool: viaDefaultPool,
    );
  }
}
