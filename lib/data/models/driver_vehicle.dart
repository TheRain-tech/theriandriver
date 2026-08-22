import 'app_enums.dart';

/// Maps node-api's `vehicles/{id}` shape (see node-api/services/vehicle.service.js#registerVehicle)
/// into the fields this app's vehicle screens already render. node-api has no "type"/"plateType"/
/// "seats"/"isDefault" concept - those come from `metadata` (round-tripped through registerVehicle's
/// `...data` spread) where this app itself supplied them, with sensible fallbacks for vehicles
/// created some other way (e.g. by an admin) that never set metadata at all.
class DriverVehicle {
  const DriverVehicle({
    required this.id,
    required this.driverId,
    required this.type,
    required this.model,
    required this.plateNumber,
    required this.plateType,
    required this.color,
    required this.seats,
    required this.isDefault,
    required this.documentStatus,
    this.imagePath,
  });

  final String id;
  final String driverId;
  final String type;
  final String model;
  final String plateNumber;
  final String plateType;
  final String color;
  final int seats;
  final bool isDefault;
  final DocumentStatus documentStatus;
  final String? imagePath;

  factory DriverVehicle.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] is Map
        ? (json['metadata'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final make = json['make']?.toString().trim() ?? '';
    final model = json['model']?.toString().trim() ?? '';
    final combinedModel = [make, model].where((part) => part.isNotEmpty).join(' ');
    return DriverVehicle(
      id: json['id']?.toString() ?? '',
      driverId: json['driverId']?.toString() ?? json['ownerId']?.toString() ?? '',
      type: metadata['serviceTier']?.toString() ?? 'Classic',
      model: combinedModel.isNotEmpty ? combinedModel : 'Vehicle',
      plateNumber: json['plateNumber']?.toString() ?? json['registrationNumber']?.toString() ?? '',
      plateType: metadata['plateType']?.toString() ?? 'Private',
      color: json['color']?.toString() ?? '',
      seats: (json['passengerCapacity'] as num?)?.toInt() ?? 4,
      isDefault: json['isDefault'] == true,
      documentStatus: _statusFromApproval(json['approvalStatus']?.toString()),
      imagePath: json['primaryImagePath']?.toString(),
    );
  }

  static DocumentStatus _statusFromApproval(String? approvalStatus) => switch (approvalStatus) {
    'APPROVED' => DocumentStatus.verified,
    'REJECTED' => DocumentStatus.rejected,
    'PENDING' => DocumentStatus.pending,
    _ => DocumentStatus.notUploaded,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'driverId': driverId,
    'type': type,
    'model': model,
    'plateNumber': plateNumber,
    'plateType': plateType,
    'color': color,
    'seats': seats,
    'isDefault': isDefault,
    'documentStatus': documentStatus.name,
    'imagePath': imagePath,
  };
}
