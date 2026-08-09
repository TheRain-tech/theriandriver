import 'package:firebase_auth/firebase_auth.dart';

import '../config/firebase_config.dart';
import 'api_client.dart';

/// A PayUnit deposit that has been initiated server-side and is now waiting on the driver to
/// approve a mobile-money prompt (or, for some gateways, finish a hosted checkout page).
class PayUnitPaymentSession {
  const PayUnitPaymentSession({
    required this.paymentId,
    required this.checkoutUrl,
    required this.status,
  });

  final String paymentId;
  final String checkoutUrl;
  final String status;

  factory PayUnitPaymentSession.fromMap(Map<String, dynamic> map) {
    return PayUnitPaymentSession(
      paymentId: (map['id'] ?? map['transactionId'])?.toString() ?? '',
      checkoutUrl: map['checkoutUrl']?.toString() ?? '',
      status: map['status']?.toString() ?? 'PENDING',
    );
  }
}

/// Real PayUnit integration, routed through node-api's driver-payroll REST API
/// (driverPayroll.routes.js `POST /:driverId/commission-wallet/deposits` ->
/// payment.service.js#initiateDriverCommissionWalletDeposit) - not the previous implementation,
/// which called a Cloud Function ("createPayUnitPaymentSession") that does not exist anywhere in
/// this project's Firebase Functions source. Every top-up attempt failed outright before this.
class PayUnitService {
  PayUnitService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  String? get _uid => FirebaseConfig.isAvailable
      ? FirebaseAuth.instance.currentUser?.uid
      : null;

  Future<PayUnitPaymentSession> createDriverCommissionTopUp({
    required double amount,
    required String method,
    required String phoneNumber,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Sign in before topping up your commission wallet.');
    }
    try {
      final response = await _apiClient.post(
        '/api/driver-payroll/$uid/commission-wallet/deposits',
        body: {'method': method, 'amount': amount, 'phoneNumber': phoneNumber},
      );
      final data = response is Map<String, dynamic>
          ? (response['data'] is Map
                ? Map<String, dynamic>.from(response['data'] as Map)
                : response)
          : <String, dynamic>{};
      return PayUnitPaymentSession.fromMap(data);
    } on ApiException catch (error) {
      throw StateError(error.message);
    }
  }
}
