import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/env_config.dart';
import '../../config/firebase_config.dart';
import '../models/auth_user.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? auth}) : _authOverride = auth;

  final FirebaseAuth? _authOverride;
  AuthUser? _mockUser;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

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

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(fullName.trim());
    final user = _mapUser(credential.user);
    if (user == null) throw StateError('Firebase did not return a user.');
    return user;
  }

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

    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = _mapUser(credential.user);
    if (user == null) throw StateError('Firebase did not return a user.');
    return user;
  }

  bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleSignInInitialized = true;
    }
  }

  Future<AuthUser> signInWithGoogle() async {
    if (!EnvConfig.googleSignInEnabled) {
      throw StateError('Google Sign-In is not configured for this build.');
    }
    if (FirebaseConfig.useMockFallback) {
      return _mockUser = AuthUser(
        uid: 'mock-driver',
        email: 'google-driver@therain.com',
        phoneNumber: '',
        displayName: 'Google Driver',
        isMock: true,
      );
    }

    await _ensureGoogleSignInInitialized();
    final googleSignIn = GoogleSignIn.instance;
    final googleUser = await googleSignIn.authenticate();

    final googleAuth = googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final firebaseCredential = await _auth.signInWithCredential(credential);
    final user = _mapUser(firebaseCredential.user);
    if (user == null) throw StateError('Firebase did not return a user.');
    return user;
  }

  Future<void> signOut() async {
    if (FirebaseConfig.useMockFallback) {
      _mockUser = null;
      return;
    }
    if (FirebaseConfig.isAvailable) {
      await _auth.signOut();
      try {
        await _ensureGoogleSignInInitialized();
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (!FirebaseConfig.isAvailable) {
      throw StateError('Firebase Authentication is unavailable.');
    }
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      phoneNumber: user.phoneNumber ?? '',
      displayName: user.displayName ?? '',
    );
  }
}
