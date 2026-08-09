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

  factory RevenueSummary.fromJson(Map<String, dynamic> json) {
    double amount(String key, {String? legacyKey}) {
      final value = json[key] ?? (legacyKey == null ? null : json[legacyKey]);
      if (value is Map) return (value['amount'] as num?)?.toDouble() ?? 0;
      return (value as num?)?.toDouble() ?? 0;
    }

    final lifetime = json['lifetime'];
    return RevenueSummary(
      today: amount('today'),
      thisWeek: amount('week', legacyKey: 'thisWeek'),
      thisMonth: amount('month', legacyKey: 'thisMonth'),
      allTime: amount('lifetime', legacyKey: 'allTime'),
      tripCount: lifetime is Map
          ? (lifetime['trips'] as num?)?.toInt() ?? 0
          : (json['tripCount'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = RevenueSummary(
    today: 0,
    thisWeek: 0,
    thisMonth: 0,
    allTime: 0,
    tripCount: 0,
  );
}
