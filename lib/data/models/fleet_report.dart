enum FleetReportReason {
  salaryCommissionDispute,
  unsafeWorkingConditions,
  harassmentAbuseDiscrimination,
  fraudulentIllegalActivity,
  other,
}

extension FleetReportReasonX on FleetReportReason {
  String get apiValue => switch (this) {
    FleetReportReason.salaryCommissionDispute => 'SALARY_COMMISSION_DISPUTE',
    FleetReportReason.unsafeWorkingConditions => 'UNSAFE_WORKING_CONDITIONS',
    FleetReportReason.harassmentAbuseDiscrimination =>
      'HARASSMENT_ABUSE_DISCRIMINATION',
    FleetReportReason.fraudulentIllegalActivity =>
      'FRAUDULENT_ILLEGAL_ACTIVITY',
    FleetReportReason.other => 'OTHER',
  };

  String get label => switch (this) {
    FleetReportReason.salaryCommissionDispute =>
      'Salary/commission dispute',
    FleetReportReason.unsafeWorkingConditions => 'Unsafe working conditions',
    FleetReportReason.harassmentAbuseDiscrimination =>
      'Harassment/abuse/discrimination',
    FleetReportReason.fraudulentIllegalActivity =>
      'Fraudulent/illegal activity',
    FleetReportReason.other => 'Other',
  };
}

/// GET/POST /api/drivers/:driverId/report-fleet + /fleet-reports
/// (node-api's driver.service.js#reportFleet, driver_fleet_reports
/// collection). Fleet drivers only — enforced both client-side (hidden for
/// TheRain-direct drivers) and server-side (403 NOT_A_FLEET_DRIVER).
class FleetReport {
  const FleetReport({
    required this.id,
    required this.reasonLabel,
    required this.description,
    required this.status,
    required this.createdAt,
    this.evidenceUrls = const [],
  });

  final String id;
  final String reasonLabel;
  final String description;
  final String status; // PENDING | UNDER_REVIEW | RESOLVED | CLOSED
  final DateTime createdAt;
  final List<String> evidenceUrls;

  factory FleetReport.fromJson(Map<String, dynamic> json) => FleetReport(
    id: json['id']?.toString() ?? '',
    reasonLabel:
        json['reasonLabel']?.toString() ?? json['reason']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    status: json['status']?.toString() ?? 'PENDING',
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    evidenceUrls: (json['evidenceUrls'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
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
