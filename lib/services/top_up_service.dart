import 'payunit_service.dart';

class TopUpService {
  TopUpService({PayUnitService? payUnitService})
    : _payUnitService = payUnitService ?? PayUnitService();

  final PayUnitService _payUnitService;

  Future<PayUnitPaymentSession> createCommissionWalletTopUp({
    required double amount,
    required String paymentMethod,
    required String phoneNumber,
  }) {
    if (amount <= 0) {
      throw StateError('Choose a top-up amount greater than zero.');
    }
    if (phoneNumber.trim().isEmpty) {
      throw StateError('Enter the mobile money number to charge.');
    }
    return _payUnitService.createDriverCommissionTopUp(
      amount: amount,
      method: paymentMethod,
      phoneNumber: phoneNumber.trim(),
    );
  }
}
