import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/data/models/revenue_summary.dart';
import 'package:theraindriver/data/models/revenue_transaction.dart';

void main() {
  test('RevenueSummary reads canonical driver-earnings buckets', () {
    final summary = RevenueSummary.fromJson({
      'today': {'amount': 1250, 'trips': 1},
      'week': {'amount': 4500, 'trips': 3},
      'month': {'amount': 9800, 'trips': 8},
      'lifetime': {'amount': 25000, 'trips': 21},
    });

    expect(summary.today, 1250);
    expect(summary.thisWeek, 4500);
    expect(summary.thisMonth, 9800);
    expect(summary.allTime, 25000);
    expect(summary.tripCount, 21);
  });

  test('RevenueTransaction reads a canonical driver-earnings record', () {
    final transaction = RevenueTransaction.fromEarningsRecord({
      'id': 'earning-1',
      'rideId': 'ride-1',
      'date': '2026-08-09',
      'time': '14:30:00',
      'tripAmount': 3000,
      'driverEarnings': 2550,
      'paymentMethod': 'Cash',
      'paymentStatus': 'SUCCESS',
    });

    expect(transaction.transactionId, 'earning-1');
    expect(transaction.rideId, 'ride-1');
    expect(transaction.date, DateTime(2026, 8, 9, 14, 30));
    expect(transaction.tripAmount, 3000);
    expect(transaction.driverEarnings, 2550);
    expect(transaction.paymentMethod, 'Cash');
  });
}
