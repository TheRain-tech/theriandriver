/// Today/Week/Month/Lifetime earnings totals — GET
/// /api/fleet-reports/drivers/:driverId/earnings (fleetReports.service.js
/// #getDriverEarningsSummary), which sums the driver's real `RIDE_EARNINGS`
/// wallet transactions server-side.
class RevenueSummary {
  const RevenueSummary({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.allTime,
    required this.tripCount,
  });

  final double today;
  final double thisWeek;
  final double thisMonth;
  final double allTime;
  final int tripCount;

  factory RevenueSummary.fromJson(Map<String, dynamic> json) =>
      RevenueSummary(
        today: (json['today'] as num?)?.toDouble() ?? 0,
        thisWeek: (json['thisWeek'] as num?)?.toDouble() ?? 0,
        thisMonth: (json['thisMonth'] as num?)?.toDouble() ?? 0,
        allTime: (json['allTime'] as num?)?.toDouble() ?? 0,
        tripCount: (json['tripCount'] as num?)?.toInt() ?? 0,
      );

  static const empty = RevenueSummary(
    today: 0,
    thisWeek: 0,
    thisMonth: 0,
    allTime: 0,
    tripCount: 0,
  );
}
