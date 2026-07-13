import '../data/models/commission_wallet.dart';
import 'payunit_service.dart';

class TopUpService {
  TopUpService({PayUnitService? payUnitService})
    : _payUnitService = payUnitService ?? PayUnitService();

  final PayUnitService _payUnitService;

  Future<PayUnitPaymentSession> createCommissionWalletTopUp({
    required CommissionWallet wallet,
    required double amount,
    required String paymentMethod,
  }) {
    if (amount <= 0) {
      throw StateError('Choose a top-up amount greater than zero.');
    }
    return _payUnitService.createPaymentSession(
      walletId: wallet.walletId,
      amount: amount,
      paymentMethod: paymentMethod,
    );
  }
}
