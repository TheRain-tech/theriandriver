enum PaymentRequestMethod { mtnMomo, orangeMoney, bankTransfer }

extension PaymentRequestMethodX on PaymentRequestMethod {
  String get apiValue => switch (this) {
    PaymentRequestMethod.mtnMomo => 'MTN_MOMO',
    PaymentRequestMethod.orangeMoney => 'ORANGE_MONEY',
    PaymentRequestMethod.bankTransfer => 'BANK_TRANSFER',
  };

  String get label => switch (this) {
    PaymentRequestMethod.mtnMomo => 'MTN Mobile Money',
    PaymentRequestMethod.orangeMoney => 'Orange Money',
    PaymentRequestMethod.bankTransfer => 'Bank Transfer',
  };

  static PaymentRequestMethod fromApiValue(String? value) =>
      switch (value?.toUpperCase()) {
        'ORANGE_MONEY' => PaymentRequestMethod.orangeMoney,
        'BANK_TRANSFER' => PaymentRequestMethod.bankTransfer,
        _ => PaymentRequestMethod.mtnMomo,
      };
}

/// TheRain-direct-driver Payment Request (node-api's driverPayroll.service.js
/// #submitPaymentRequest / driver_payment_requests collection).
/// Pending -> Approved -> Paid, or Rejected.
class PaymentRequest {
  const PaymentRequest({
    required this.id,
    required this.amount,
    required this.paymentMethod,
    required this.accountDetails,
    required this.status,
    required this.requestedAt,
    this.notes,
    this.rejectionReason,
    this.paidAt,
    this.transactionReference,
    this.remainingBalance,
  });

  final String id;
  final double amount;
  final PaymentRequestMethod paymentMethod;
  final String accountDetails;
  final String status; // PENDING | APPROVED | REJECTED | PAID
  final DateTime requestedAt;
  final String? notes;
  final String? rejectionReason;
  final DateTime? paidAt;
  final String? transactionReference;
  final double? remainingBalance;

  bool get isOpen => status == 'PENDING' || status == 'APPROVED';

  factory PaymentRequest.fromJson(Map<String, dynamic> json) => PaymentRequest(
    id: json['id']?.toString() ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    paymentMethod: PaymentRequestMethodX.fromApiValue(
      json['paymentMethod']?.toString(),
    ),
    accountDetails: json['accountDetails']?.toString() ?? '',
    status: json['status']?.toString() ?? 'PENDING',
    requestedAt: _date(json['requestedAt']) ?? DateTime.now(),
    notes: json['notes']?.toString(),
    rejectionReason: json['rejectionReason']?.toString(),
    paidAt: _date(json['paidAt']),
    transactionReference: json['transactionReference']?.toString(),
    remainingBalance: (json['remainingBalance'] as num?)?.toDouble(),
  );

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          (seconds as num).toInt() * 1000,
        );
      }
    }
    return null;
  }
}
