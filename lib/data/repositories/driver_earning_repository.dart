import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../config/env_config.dart';
import '../../config/firebase_config.dart';
import '../../firebase/firestore_collections.dart';
import '../mock/mock_driver_earnings.dart';
import '../models/driver_earning.dart';

class DriverEarningRepository {
  DriverEarningRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  Future<List<DriverEarning>> getEarnings({String period = 'Weekly'}) async {
    final uid = FirebaseConfig.isAvailable
        ? FirebaseAuth.instance.currentUser?.uid
        : null;
    if (uid == null || !FirebaseConfig.isAvailable) {
      if (EnvConfig.previewMode || FirebaseConfig.useMockFallback) {
        final mock = mockDriverEarnings.first;
        final factor = period == 'Daily' ? 0.15 : (period == 'Monthly' ? 4.0 : 1.0);
        final results = [
          DriverEarning(
            id: '${period.toLowerCase()}-${mock.id}',
            driverId: mock.driverId,
            period: period,
            total: mock.total * factor,
            baseFares: mock.baseFares * factor,
            bonuses: mock.bonuses * factor,
            tips: mock.tips * factor,
            deductions: mock.deductions * factor,
            tripCount: (mock.tripCount * factor).round(),
            onlineMinutes: (mock.onlineMinutes * factor).round(),
            createdAt: mock.createdAt,
          ),
        ];

        if (period == 'Weekly') {
          for (int i = 0; i < 7; i++) {
            results.add(
              DriverEarning(
                id: 'day-$i',
                driverId: mock.driverId,
                period: 'Daily',
                total: mockWeeklyChart[i] * 1000,
                baseFares: mockWeeklyChart[i] * 800,
                bonuses: mockWeeklyChart[i] * 100,
                tips: mockWeeklyChart[i] * 100,
                deductions: 0,
                tripCount: (mockWeeklyChart[i] / 5).round(),
                onlineMinutes: (mockWeeklyChart[i] * 30).round(),
                createdAt: DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1 - i)),
              ),
            );
          }
        }
        return results;
      }
      return const [];
    }

    final now = DateTime.now();
    DateTime start;
    if (period == 'Daily') {
      start = DateTime(now.year, now.month, now.day);
    } else if (period == 'Monthly') {
      start = DateTime(now.year, now.month, 1);
    } else {
      // Weekly
      start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    }

    final snapshot = await _db
        .collection(FirestoreCollections.driverTransactions)
        .where('driverId', isEqualTo: uid)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .get();

    var ridePayments = 0.0;
    var bonuses = 0.0;
    var tips = 0.0;
    var deductions = 0.0;
    var tripCount = 0;

    final dailyTotals = List.filled(7, 0.0);

    for (final document in snapshot.docs) {
      final data = document.data();
      final statusStr = data['status']?.toString().toLowerCase();
      if (statusStr != 'completed' && statusStr != 'paid') continue;

      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final typeStr = data['type']?.toString();
      final createdAtTimestamp = data['createdAt'] as Timestamp?;
      final createdAtDate = createdAtTimestamp?.toDate() ?? DateTime.now();

      if (period == 'Weekly') {
        final dayIndex = createdAtDate.weekday - 1;
        if (dayIndex >= 0 && dayIndex < 7) {
          if (typeStr == 'ridePayment' || typeStr == 'earning' || typeStr == 'bonus' || typeStr == 'tip') {
            dailyTotals[dayIndex] += amount;
          } else if (typeStr == 'deduction') {
            dailyTotals[dayIndex] -= amount.abs();
          }
        }
      }

      switch (typeStr) {
        case 'ridePayment':
        case 'earning':
          ridePayments += amount;
          tripCount++;
          break;
        case 'bonus':
          bonuses += amount;
          break;
        case 'tip':
          tips += amount;
          break;
        case 'deduction':
          deductions += amount.abs();
          break;
      }
    }

    final total = ridePayments + bonuses + tips - deductions;
    final summary = DriverEarning(
      id: '${period.toLowerCase()}-${start.toIso8601String()}',
      driverId: uid,
      period: period,
      total: total,
      baseFares: ridePayments,
      bonuses: bonuses,
      tips: tips,
      deductions: deductions,
      tripCount: tripCount,
      onlineMinutes: 0,
      createdAt: start,
    );

    final results = [summary];

    if (period == 'Weekly') {
      for (int i = 0; i < 7; i++) {
        final dayDate = start.add(Duration(days: i));
        results.add(
          DriverEarning(
            id: 'day-$i-${dayDate.toIso8601String()}',
            driverId: uid,
            period: 'Daily',
            total: dailyTotals[i],
            baseFares: 0,
            bonuses: 0,
            tips: 0,
            deductions: 0,
            tripCount: 0,
            onlineMinutes: 0,
            createdAt: dayDate,
          ),
        );
      }
    }

    return results;
  }
}
