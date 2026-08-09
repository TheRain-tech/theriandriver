import 'package:flutter/material.dart';

import '../../config/env_config.dart';
import '../../config/firebase_config.dart';
import '../../services/auth_service.dart';
import '../mock/mock_driver_earnings.dart';
import '../models/driver_earning.dart';
import 'driver_revenue_repository.dart';

/// Real earnings, backed by the same node-api wallet transactions the Wallet screen reads
/// (driverPayroll.service.js#creditDriverForRide -> wallets/driver_{id}, reason
/// "RIDE_EARNINGS") via DriverRevenueRepository - not a direct query against this app's own
/// `driver_transactions` Firestore collection like this repository used to run. That collection
/// is never written by anything in node-api (grep-confirmed: the constant is declared but no
/// service ever calls createDoc/updateDoc against it), and the query itself
/// (`where('driverId','==',uid).where('createdAt','>=',start)`) needs a composite index that was
/// never deployed either - so every call threw before returning, which is exactly the "We could
/// not load your earnings. Please try again." the Earnings screen always showed. Reproduced live
/// on a physical device.
class DriverEarningRepository {
  DriverEarningRepository({DriverRevenueRepository? revenueRepository})
    : _revenueRepository = revenueRepository ?? DriverRevenueRepository();

  final DriverRevenueRepository _revenueRepository;

  Future<List<DriverEarning>> getEarnings({
    String period = 'Weekly',
    DateTimeRange? dateRange,
  }) async {
    final uid = FirebaseConfig.isAvailable
        ? AuthService.instance.currentUserId
        : null;
    if (uid == null || !FirebaseConfig.isAvailable) {
      return EnvConfig.previewMode || FirebaseConfig.useMockFallback
          ? _mockEarnings(period)
          : const [];
    }

    final now = DateTime.now();
    final DateTime start;
    if (dateRange != null) {
      start = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
      );
    } else if (period == 'Daily') {
      start = DateTime(now.year, now.month, now.day);
    } else if (period == 'Monthly') {
      start = DateTime(now.year, now.month, 1);
    } else {
      // Weekly - Monday as the first day, matching the dashboard's day-label order below.
      start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
    }

    final end = dateRange == null
        ? now
        : DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day);
    final inRange = await _revenueRepository.getTransactions(
      uid,
      from: start,
      to: end,
    );
    final total = inRange.fold(0.0, (sum, t) => sum + t.driverEarnings);

    final summary = DriverEarning(
      id: '${dateRange == null ? period.toLowerCase() : 'custom'}-${start.toIso8601String()}',
      driverId: uid,
      period: dateRange == null ? period : 'Custom',
      total: total,
      // No base/bonus/tip/deduction split is available from wallet transactions alone (a
      // RIDE_EARNINGS credit is already net) - reported as all base fare rather than fabricating
      // a breakdown, so Base Fare + Bonuses + Tips - Deductions still reconciles to `total`.
      baseFares: total,
      bonuses: 0,
      tips: 0,
      deductions: 0,
      tripCount: inRange.length,
      onlineMinutes: 0,
      createdAt: start,
    );

    final results = [summary];

    if (period == 'Weekly') {
      final dailyTotals = List.filled(7, 0.0);
      for (final transaction in inRange) {
        final dayIndex = transaction.date.weekday - 1;
        if (dayIndex >= 0 && dayIndex < 7) {
          dailyTotals[dayIndex] += transaction.driverEarnings;
        }
      }
      for (int i = 0; i < 7; i++) {
        final dayDate = start.add(Duration(days: i));
        results.add(
          DriverEarning(
            id: 'day-$i-${dayDate.toIso8601String()}',
            driverId: uid,
            period: 'Daily',
            total: dailyTotals[i],
            baseFares: dailyTotals[i],
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

  List<DriverEarning> _mockEarnings(String period) {
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
            createdAt: DateTime.now().subtract(
              Duration(days: DateTime.now().weekday - 1 - i),
            ),
          ),
        );
      }
    }
    return results;
  }
}
