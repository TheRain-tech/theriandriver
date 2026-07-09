import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_config.dart';

class OtpService {
  OtpService._();
  static final instance = OtpService._();

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: FirebaseConfig.functionsRegion);

  /// Sends a WhatsApp OTP to [phone] via the Twilio backend.
  /// Throws [FirebaseFunctionsException] on backend error.
  Future<void> sendWhatsAppOtp(String phone) async {
    if (!FirebaseConfig.isAvailable) return;
    await _functions.httpsCallable('sendWhatsAppOtp').call({'phone': phone});
  }

  /// Verifies [code] for [phone]. Returns true if the backend confirmed the code.
  /// The backend marks drivers/{uid}.phoneVerified = true on success via admin SDK.
  Future<bool> verifyWhatsAppOtp(String phone, String code) async {
    if (!FirebaseConfig.isAvailable) return false;
    try {
      final result = await _functions.httpsCallable('verifyWhatsAppOtp').call({
        'phone': phone,
        'code': code,
      });
      final data = result.data;
      if (data is Map) return data['verified'] == true;
      return false;
    } catch (e) {
      debugPrint('OTP verify error: $e');
      return false;
    }
  }
}
