import 'package:cloud_firestore/cloud_firestore.dart';

class DriverWallet {
  const DriverWallet({
    required this.id,
    required this.driverId,
    required this.balance,
    required this.availableToWithdraw,
    required this.minimumWithdrawal,
    required this.payoutMethod,
    required this.payoutAccount,
    required this.updatedAt,
    this.pendingBalance = 0,
  });

  final String id;
  final String driverId;
  final double balance;
  final double availableToWithdraw;
  final double minimumWithdrawal;
  final String payoutMethod;
  final String payoutAccount;
  final DateTime updatedAt;
  final double pendingBalance;

  factory DriverWallet.fromMap(Map<String, dynamic> map, String id) {
    final payout =
        (map['defaultPayoutMethod'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final provider = payout['provider']?.toString() ?? '';
    final phoneNumber = payout['phoneNumber']?.toString() ?? '';
    return DriverWallet(
      id: id,
      driverId: map['driverId']?.toString() ?? id,
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      availableToWithdraw:
          (map['availableToWithdraw'] as num?)?.toDouble() ?? 0,
      minimumWithdrawal: (map['minimumWithdrawal'] as num?)?.toDouble() ?? 5000,
      payoutMethod: provider.isEmpty ? 'Mobile Money' : provider,
      payoutAccount: phoneNumber.isEmpty
          ? 'No payout number configured'
          : phoneNumber,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      pendingBalance: (map['pendingBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory DriverWallet.fromJson(Map<String, dynamic> json) => DriverWallet(
    id: json['id'] as String,
    driverId: json['driverId'] as String,
    balance: (json['balance'] as num).toDouble(),
    availableToWithdraw: (json['availableToWithdraw'] as num).toDouble(),
    minimumWithdrawal: (json['minimumWithdrawal'] as num).toDouble(),
    payoutMethod: json['payoutMethod'] as String,
    payoutAccount: json['payoutAccount'] as String,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    pendingBalance: (json['pendingBalance'] as num?)?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'driverId': driverId,
    'balance': balance,
    'availableToWithdraw': availableToWithdraw,
    'pendingBalance': pendingBalance,
    'currency': 'XAF',
    'defaultPayoutMethod': {
      'type': 'mobileMoney',
      'provider': payoutMethod,
      'phoneNumber': payoutAccount,
    },
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
