import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the `suspension` object node-api's driver.service.js#suspend()
/// writes onto `drivers/{driverId}` (reasonCategory/reasonLabel/subReason/
/// adminNotes/suspendedBy/adminRole/suspensionDate/fleetId/fleetName/
/// regionId). Read directly off the driver document the app already streams.
class DriverSuspension {
  const DriverSuspension({
    this.id,
    this.reasonCategory,
    this.reasonLabel,
    this.subReason,
    this.adminNotes,
    this.suspendedBy,
    this.adminRole,
    this.suspensionDate,
    this.fleetId,
    this.fleetName,
  });

  final String? id;
  final String? reasonCategory;
  final String? reasonLabel;
  final String? subReason;
  final String? adminNotes;
  final String? suspendedBy;
  final String? adminRole;
  final DateTime? suspensionDate;
  final String? fleetId;
  final String? fleetName;

  static DriverSuspension? fromMap(Object? value) {
    if (value is! Map) return null;
    final map = value.map((key, val) => MapEntry(key.toString(), val));
    return DriverSuspension(
      id: map['id']?.toString() ?? map['suspensionId']?.toString(),
      reasonCategory: map['reasonCategory']?.toString(),
      reasonLabel: map['reasonLabel']?.toString(),
      subReason: map['subReason']?.toString(),
      adminNotes: map['adminNotes']?.toString(),
      suspendedBy: map['suspendedBy']?.toString(),
      adminRole: map['adminRole']?.toString(),
      suspensionDate: _date(map['suspensionDate']),
      fleetId: map['fleetId']?.toString(),
      fleetName: map['fleetName']?.toString(),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
