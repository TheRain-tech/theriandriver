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
    status: enumByName(
      DocumentStatus.values,
      json['status'],
      DocumentStatus.notUploaded,
    ),
    filePath: json['filePath'] as String?,
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.parse(json['expiresAt'] as String),
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.parse(json['updatedAt'] as String),
  );

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
