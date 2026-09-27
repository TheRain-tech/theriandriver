import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class OtpRequestResult {
  final String verificationId;
  final int? resendToken;
  // Set only when Android's SMS auto-retrieval verified the device without the user typing
  // anything - the OTP sheet can finish immediately instead of waiting for input.
  final PhoneAuthCredential? autoCredential;

  const OtpRequestResult({
    required this.verificationId,
    this.resendToken,
    this.autoCredential,
  });
}

// Firebase's own Phone Auth (real carrier SMS/WhatsApp-independent, Google-run infrastructure) -
// not OtpService's Twilio Verify WhatsApp integration, which is rider-only (requireRiderRole in
// functions-rider-auth/index.js rejects any caller that isn't a rider) and was never funded for
// production use. A driver calling it got a request rejected before Twilio was ever reached -
// a completely different error shape than the reCAPTCHA/Play-Integrity path real Firebase Phone
// Auth uses elsewhere in the app, which is exactly what this replaces it with.
class PhoneAuthService {
  final FirebaseAuth _auth;

  PhoneAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  Future<OtpRequestResult> requestOtp({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    final completer = Completer<OtpRequestResult>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResendingToken,
      verificationCompleted: (PhoneAuthCredential credential) {
        if (completer.isCompleted) return;
        completer.complete(
          OtpRequestResult(
            verificationId: credential.verificationId ?? '',
            autoCredential: credential,
          ),
        );
      },
      verificationFailed: (FirebaseAuthException error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (completer.isCompleted) return;
        completer.complete(
          OtpRequestResult(verificationId: verificationId, resendToken: resendToken),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) {
          completer.complete(OtpRequestResult(verificationId: verificationId));
        }
      },
    );

    return completer.future;
  }

  // Attaches the verified number to the ALREADY-signed-in driver (email/password account) rather
  // than signing in/switching accounts - a driver proves phone ownership, they don't authenticate
  // with it. If this exact number is already linked to a different Firebase user (rare, but
  // possible if a driver re-registers under a new email), the code itself was still verified
  // correctly - the caller treats credential-already-in-use as a successful verification too,
  // rather than surfacing a confusing "in use" error for something the driver did nothing wrong in.
  Future<void> linkPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in account to verify a phone number for.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'credential-already-in-use' && error.code != 'provider-already-linked') {
        rethrow;
      }
    }
  }
}
