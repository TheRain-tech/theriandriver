import 'package:cloud_firestore/cloud_firestore.dart';

class CommissionWallet {
  const CommissionWallet({
    required this.walletId,
    required this.ownerType,
    required this.ownerId,
    required this.balance,
    required this.currency,
    required this.minimumRequiredBalance,
    required this.lowBalanceThreshold,
    required this.status,
    required this.updatedAt,
  });

  final String walletId;
  final String ownerType;
  final String ownerId;
  final double balance;
  final String currency;
  final double minimumRequiredBalance;
  final double lowBalanceThreshold;
  final String status;
  final DateTime updatedAt;

  bool get canReceiveRides =>
      status == 'active' && balance >= minimumRequiredBalance;

  bool get isLow =>
      status == 'low_balance' ||
      (balance > minimumRequiredBalance && balance <= lowBalanceThreshold);

  factory CommissionWallet.empty({
    required String walletId,
    required String ownerType,
    required String ownerId,
  }) {
    return CommissionWallet(
      walletId: walletId,
      ownerType: ownerType,
      ownerId: ownerId,
      balance: 0,
      currency: 'XAF',
      minimumRequiredBalance: 1,
      lowBalanceThreshold: 1000,
      status: 'empty',
      updatedAt: DateTime.now(),
    );
  }

  factory CommissionWallet.fromMap(Map<String, dynamic> map, String id) {
    return CommissionWallet(
      walletId: map['walletId']?.toString() ?? id,
      ownerType: map['ownerType']?.toString() ?? 'driver',
      ownerId: map['ownerId']?.toString() ?? id,
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      currency: map['currency']?.toString() ?? 'XAF',
      minimumRequiredBalance:
          (map['minimumRequiredBalance'] as num?)?.toDouble() ?? 1,
      lowBalanceThreshold:
          (map['lowBalanceThreshold'] as num?)?.toDouble() ?? 1000,
      status: map['status']?.toString() ?? 'empty',
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class CommissionWalletEligibility {
  const CommissionWalletEligibility({
    required this.allowed,
    required this.reason,
    this.wallet,
  });

  final bool allowed;
  final String reason;
  final CommissionWallet? wallet;

  static CommissionWalletEligibility allowedWith(CommissionWallet wallet) =>
      CommissionWalletEligibility(
        allowed: true,
        reason: wallet.isLow
            ? 'Commission balance is low. Top up soon.'
            : 'Commission wallet ready.',
        wallet: wallet,
      );

  static CommissionWalletEligibility blocked(
    String reason, {
    CommissionWallet? wallet,
  }) => CommissionWalletEligibility(
    allowed: false,
    reason: reason,
    wallet: wallet,
  );
}
