import '../models/driver_earning.dart';

final mockDriverEarnings = <DriverEarning>[
  DriverEarning(
    id: 'earning-week-001',
    driverId: 'driver-001',
    period: 'Weekly',
    total: 125600,
    baseFares: 85400,
    bonuses: 20300,
    tips: 15900,
    deductions: 6000,
    tripCount: 48,
    onlineMinutes: 1965,
    createdAt: DateTime(2026, 6, 6),
  ),
];

const mockWeeklyChart = <double>[16, 28, 20, 14, 22, 29, 24];
