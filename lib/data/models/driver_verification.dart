import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_enums.dart';

class DriverVerification {
  const DriverVerification({
    required this.id,
    required this.driverId,
    required this.status,
    this.nationalIdNumber,
    this.licenceNumber,
    this.licenceExpiry,
    this.nationalIdPath,
    this.licencePath,
    this.selfiePath,
    this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
    this.reviewedBy,
    this.resubmissionCount = 0,
  });

  final String id;
  final String driverId;
  final DriverVerificationStatus status;
  final String? nationalIdNumber;
  final String? licenceNumber;
  final DateTime? licenceExpiry;
  final String? nationalIdPath;
  final String? licencePath;
  final String? selfiePath;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final String? reviewedBy;
  final int resubmissionCount;

  DriverVerification copyWith({DriverVerificationStatus? status}) {
    return DriverVerification(
      id: id,
      driverId: driverId,
      status: status ?? this.status,
      nationalIdNumber: nationalIdNumber,
      licenceNumber: licenceNumber,
      licenceExpiry: licenceExpiry,
      nationalIdPath: nationalIdPath,
      licencePath: licencePath,
      selfiePath: selfiePath,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt,
      rejectionReason: rejectionReason,
      reviewedBy: reviewedBy,
      resubmissionCount: resubmissionCount,
    );
  }

  factory DriverVerification.fromJson(Map<String, dynamic> json) =>
      DriverVerification.fromMap(json, json['id']?.toString() ?? '');

  factory DriverVerification.fromMap(Map<String, dynamic> map, String id) =>
      DriverVerification(
        id: id,
        driverId: map['driverId']?.toString() ?? id,
        status: enumByName(
          DriverVerificationStatus.values,
          map['status'],
          DriverVerificationStatus.notStarted,
        ),
        nationalIdNumber: map['nationalIdNumber']?.toString(),
        licenceNumber:
            map['driverLicenceNumber']?.toString() ??
            map['licenceNumber']?.toString(),
        licenceExpiry:
            _date(map['driverLicenceExpiryDate']) ??
            _date(map['licenceExpiry']),
        nationalIdPath:
            map['nationalIdPhotoPath']?.toString() ??
            map['nationalIdPath']?.toString(),
        licencePath:
            map['driverLicencePhotoPath']?.toString() ??
            map['licencePath']?.toString(),
        selfiePath:
            map['selfiePhotoPath']?.toString() ?? map['selfiePath']?.toString(),
        submittedAt: _date(map['submittedAt']),
        reviewedAt: _date(map['reviewedAt']),
        rejectionReason: map['rejectionReason']?.toString(),
        reviewedBy: map['reviewedBy']?.toString(),
        resubmissionCount: (map['resubmissionCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'driverId': driverId,
    'status': status.name,
    'nationalIdNumber': nationalIdNumber,
    'licenceNumber': licenceNumber,
    'licenceExpiry': licenceExpiry?.toIso8601String(),
    'nationalIdPath': nationalIdPath,
    'licencePath': licencePath,
    'selfiePath': selfiePath,
    'submittedAt': submittedAt?.toIso8601String(),
    'reviewedAt': reviewedAt?.toIso8601String(),
    'rejectionReason': rejectionReason,
    'reviewedBy': reviewedBy,
    'resubmissionCount': resubmissionCount,
  };

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
