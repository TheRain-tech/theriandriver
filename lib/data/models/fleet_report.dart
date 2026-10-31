import '../../core/localization/driver_copy.dart';

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
    FleetReportReason.salaryCommissionDispute => 'Salary/commission dispute',
    FleetReportReason.unsafeWorkingConditions => 'Unsafe working conditions',
    FleetReportReason.harassmentAbuseDiscrimination =>
      'Harassment/abuse/discrimination',
    FleetReportReason.fraudulentIllegalActivity =>
      'Fraudulent/illegal activity',
    FleetReportReason.other => 'Other',
  };

  // node-api's FLEET_REPORT_REASONS labels are English-only (utils/constants.js) - this is the
  // one place that translates them for display, used both for the reason picker and (via
  // reasonFromApiValue below) for re-localizing a submitted report's reason in Your Reports,
  // which otherwise always shows the backend's English reasonLabel regardless of app language.
  String localizedLabel(DriverCopy l) => switch (this) {
    FleetReportReason.salaryCommissionDispute => l.t(
        'Salary/commission dispute',
        'Litige salarial/sur commission',
      ),
    FleetReportReason.unsafeWorkingConditions => l.t(
        'Unsafe working conditions',
        'Conditions de travail dangereuses',
      ),
    FleetReportReason.harassmentAbuseDiscrimination => l.t(
        'Harassment/abuse/discrimination',
        'Harcèlement/abus/discrimination',
      ),
    FleetReportReason.fraudulentIllegalActivity => l.t(
        'Fraudulent/illegal activity',
        'Activité frauduleuse/illégale',
      ),
    FleetReportReason.other => l.t('Other', 'Autre'),
  };
}

/// Reverse lookup from node-api's reason key (FleetReport.reason) back to the
/// local enum, so a report fetched from Your Reports can be re-localized
/// instead of only ever showing the backend's English reasonLabel.
FleetReportReason? reasonFromApiValue(String? apiValue) {
  for (final reason in FleetReportReason.values) {
    if (reason.apiValue == apiValue) return reason;
  }
  return null;
}

/// GET/POST /api/drivers/:driverId/report-fleet + /fleet-reports
/// (node-api's driver.service.js#reportFleet, driver_fleet_reports
/// collection). Fleet drivers only — enforced both client-side (hidden for
/// TheRain-direct drivers) and server-side (403 NOT_A_FLEET_DRIVER).
class FleetReport {
  const FleetReport({
    required this.id,
    required this.reason,
    required this.reasonLabel,
    required this.description,
    required this.status,
    required this.createdAt,
    this.evidenceUrls = const [],
  });

  final String id;
  final String reason; // raw backend key, e.g. UNSAFE_WORKING_CONDITIONS
  final String reasonLabel;
  final String description;
  final String status; // PENDING | UNDER_REVIEW | RESOLVED | CLOSED
  final DateTime createdAt;
  final List<String> evidenceUrls;

  // Prefers the local, language-aware translation over the backend's English-only
  // reasonLabel when the reason key is one this app knows about.
  String localizedReasonLabel(DriverCopy l) {
    final matched = reasonFromApiValue(reason);
    if (matched != null) return matched.localizedLabel(l);
    return reasonLabel;
  }

  factory FleetReport.fromJson(Map<String, dynamic> json) => FleetReport(
    id: json['id']?.toString() ?? '',
    reason: json['reason']?.toString() ?? '',
    reasonLabel:
        json['reasonLabel']?.toString() ?? json['reason']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    status: json['status']?.toString() ?? 'PENDING',
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    evidenceUrls:
        (json['evidenceUrls'] as List?)?.map((e) => e.toString()).toList() ??
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
