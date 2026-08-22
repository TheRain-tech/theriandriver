import 'app_enums.dart';

class DriverDocument {
  const DriverDocument({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    required this.type,
    required this.status,
    this.filePath,
    this.expiresAt,
    this.updatedAt,
  });

  final String id;
  final String driverId;
  final String? vehicleId;
  final String type;
  final DocumentStatus status;
  final String? filePath;
  final DateTime? expiresAt;
  final DateTime? updatedAt;

  factory DriverDocument.fromJson(Map<String, dynamic> json) => DriverDocument(
    id: json['id'] as String,
    driverId: json['driverId'] as String,
    vehicleId: json['vehicleId'] as String?,
    type: json['type'] as String,
    status: _statusFromNodeApi(json['status']?.toString()),
    filePath: json['filePath'] as String?,
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.parse(json['expiresAt'] as String),
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.parse(json['updatedAt'] as String),
  );

  /// node-api's DOCUMENT_VERIFICATION_STATUS (PENDING_VERIFICATION/VERIFIED/REJECTED) doesn't
  /// name-match this app's DocumentStatus enum (notUploaded/uploaded/pending/verified/rejected) -
  /// enumByName's exact-name match would silently fall back to notUploaded for every real value.
  static DocumentStatus _statusFromNodeApi(String? status) => switch (status) {
    'VERIFIED' => DocumentStatus.verified,
    'REJECTED' => DocumentStatus.rejected,
    'PENDING_VERIFICATION' => DocumentStatus.pending,
    _ => DocumentStatus.notUploaded,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'driverId': driverId,
    'vehicleId': vehicleId,
    'type': type,
    'status': status.name,
    'filePath': filePath,
    'expiresAt': expiresAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}
