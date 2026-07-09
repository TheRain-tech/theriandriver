import 'package:cloud_functions/cloud_functions.dart';

import '../config/firebase_config.dart';

class PayUnitPaymentSession {
  const PayUnitPaymentSession({
    required this.sessionId,
    required this.checkoutUrl,
    required this.status,
  });

  final String sessionId;
  final String checkoutUrl;
  final String status;

  factory PayUnitPaymentSession.fromMap(Map<String, dynamic> map) {
    return PayUnitPaymentSession(
      sessionId: map['sessionId']?.toString() ?? '',
      checkoutUrl: map['checkoutUrl']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
    );
  }
}

class PayUnitService {
  PayUnitService({FirebaseFunctions? functions})
    : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: FirebaseConfig.functionsRegion);

  Future<PayUnitPaymentSession> createPaymentSession({
    required String walletId,
    required double amount,
    required String paymentMethod,
  }) async {
    if (!FirebaseConfig.isAvailable) {
      throw StateError('Payment backend is unavailable.');
    }
    final result = await _functions
        .httpsCallable('createPayUnitPaymentSession')
        .call({
          'walletId': walletId,
          'amount': amount,
          'currency': 'XAF',
          'paymentMethod': paymentMethod,
        });
    return PayUnitPaymentSession.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }
}
