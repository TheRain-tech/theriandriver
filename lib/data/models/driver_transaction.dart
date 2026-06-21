import 'app_enums.dart';

class DriverTransaction {
  const DriverTransaction({
    required this.id,
    required this.driverId,
    required this.title,
    required this.type,
    required this.amount,
    required this.createdAt,
    required this.status,
    this.reference,
  });

  final String id;
  final String driverId;
  final String title;
  final String type;
  final double amount;
  final DateTime createdAt;
  final WithdrawalStatus status;
  final String? reference;

  factory DriverTransaction.fromJson(Map<String, dynamic> json) =>
      DriverTransaction(
        id: json['id'] as String,
        driverId: json['driverId'] as String,
        title: json['title'] as String,
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: enumByName(
          WithdrawalStatus.values,
          json['status'],
          WithdrawalStatus.completed,
        ),
        reference: json['reference'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'driverId': driverId,
    'title': title,
    'type': type,
    'amount': amount,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'reference': reference,
  };
}
