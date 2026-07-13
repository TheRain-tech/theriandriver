/// GET /api/drivers/:driverId/fleet-agreement
/// (node-api's driver.service.js#getDriverFleetAgreement).
class FleetAgreement {
  const FleetAgreement({
    required this.driverId,
    required this.driverName,
    required this.fleetId,
    required this.fleetName,
    required this.status,
    this.agreementStartDate,
    required this.contractSummary,
    required this.agreementId,
  });

  final String driverId;
  final String? driverName;
  final String fleetId;
  final String? fleetName;
  final String status;
  final DateTime? agreementStartDate;
  final String contractSummary;
  final String agreementId;

  factory FleetAgreement.fromJson(Map<String, dynamic> json) =>
      FleetAgreement(
        driverId: json['driverId']?.toString() ?? '',
        driverName: json['driverName']?.toString(),
        fleetId: json['fleetId']?.toString() ?? '',
        fleetName: json['fleetName']?.toString(),
        status: json['status']?.toString() ?? 'ACTIVE',
        agreementStartDate: _date(json['agreementStartDate']),
        contractSummary: json['contractSummary']?.toString() ?? '',
        agreementId: json['agreementId']?.toString() ?? '',
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
