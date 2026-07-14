/// One row of "Recent Transactions" / Revenue History: a completed trip
/// joined with the wallet transaction node-api's driverPayroll.service.js
/// #creditDriverForRide actually credited for it. The wallet transaction
/// (RIDE_EARNINGS) is the source of truth for what the driver was paid; the
/// matching ride document (fetched separately, joined client-side by
/// rideId) fills in the trip's full fare/payment method/fleet — best-effort
/// only, since older wallet transactions may not have a resolvable ride.
class RevenueTransaction {
  const RevenueTransaction({
    required this.transactionId,
    required this.rideId,
    required this.date,
    required this.driverEarnings,
    this.tripAmount,
    this.paymentMethod,
    this.status,
    this.fleetName,
  });

  final String transactionId;
  final String? rideId;
  final DateTime date;
  final double driverEarnings;
  final double? tripAmount;
  final String? paymentMethod;
  final String? status;
  final String? fleetName;

  factory RevenueTransaction.fromWalletTransaction(
    Map<String, dynamic> json, {
    Map<String, dynamic>? ride,
    String? fleetName,
  }) {
    final metadata = json['metadata'] is Map
        ? (json['metadata'] as Map).map((k, v) => MapEntry(k.toString(), v))
        : const <String, dynamic>{};
    final rideId =
        json['referenceId']?.toString() ?? metadata['rideId']?.toString();

    double? tripAmount;
    String? paymentMethod;
    String? status;
    if (ride != null) {
      final pricing = ride['pricing'];
      if (pricing is Map && pricing['total'] != null) {
        tripAmount = (pricing['total'] as num?)?.toDouble();
      }
      tripAmount ??= (ride['fare'] as num?)?.toDouble();
      tripAmount ??= (ride['amount'] as num?)?.toDouble();
      paymentMethod = ride['paymentMethod']?.toString();
      status = ride['status']?.toString();
    }

    return RevenueTransaction(
      transactionId: json['id']?.toString() ?? '',
      rideId: rideId,
      date: _date(json['createdAt']) ?? DateTime.now(),
      driverEarnings: (json['amount'] as num?)?.toDouble() ?? 0,
      tripAmount: tripAmount,
      paymentMethod: paymentMethod,
      status: status ?? 'completed',
      fleetName: fleetName,
    );
  }

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
