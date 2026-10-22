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
    this.source,
    this.uploadedByFleet = false,
    this.originalName,
  });

  final String id;
  final String driverId;
  final String? vehicleId;
  final String type;
  final DocumentStatus status;
  final String? filePath;
  final DateTime? expiresAt;
  final DateTime? updatedAt;
  final String? source;
  final bool uploadedByFleet;
  final String? originalName;

  bool get isReusableFleetEvidence =>
      (uploadedByFleet || source == 'fleet_invitation') &&
      filePath?.trim().isNotEmpty == true &&
      status != DocumentStatus.rejected;

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : const <String, dynamic>{};
    final file = json['file'] is Map
        ? Map<String, dynamic>.from(json['file'] as Map)
        : const <String, dynamic>{};
    final explicitFilePath = json['filePath']?.toString();
    final filePathCandidates = [
      explicitFilePath,
      metadata['filePath']?.toString(),
      file['path']?.toString(),
      file['storagePath']?.toString(),
      file['filePath']?.toString(),
    ];
    final resolvedFilePath = filePathCandidates.firstWhere(
      (candidate) => candidate != null && candidate.trim().isNotEmpty,
      orElse: () => null,
    );
    final rawStatus = json['status'];
    final sourceValue =
        json['source']?.toString() ?? metadata['source']?.toString();
    final uploadedByFleet =
        json['uploadedByFleet'] == true || metadata['uploadedByFleet'] == true;

    return DriverDocument(
      id: (json['id'] ?? '').toString(),
      driverId: (json['driverId'] ?? '').toString(),
      vehicleId: json['vehicleId']?.toString(),
      type: (json['type'] ?? '').toString(),
      status: _statusFromNodeApi(rawStatus is DocumentStatus
          ? rawStatus.name
          : rawStatus?.toString()),
      filePath: resolvedFilePath,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.tryParse(json['expiresAt'].toString()),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'].toString()),
      source: sourceValue,
      uploadedByFleet: uploadedByFleet,
      originalName: metadata['originalName']?.toString() ??
          json['originalName']?.toString(),
    );
  }

  /// node-api's DOCUMENT_VERIFICATION_STATUS (PENDING_VERIFICATION/VERIFIED/REJECTED) doesn't
  /// name-match this app's DocumentStatus enum (notUploaded/uploaded/pending/verified/rejected) -
  /// enumByName's exact-name match would silently fall back to notUploaded for every real value.
  static DocumentStatus _statusFromNodeApi(String? status) => switch (status) {
    'VERIFIED' || 'verified' => DocumentStatus.verified,
    'REJECTED' || 'rejected' => DocumentStatus.rejected,
    'PENDING_VERIFICATION' || 'pending' || 'PENDING' => DocumentStatus.pending,
    'UPLOADED' || 'uploaded' => DocumentStatus.uploaded,
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
    'metadata': {
      if (source != null) 'source': source,
      if (uploadedByFleet) 'uploadedByFleet': true,
      if (originalName != null) 'originalName': originalName,
    },
  };
}
