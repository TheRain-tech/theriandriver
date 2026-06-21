import 'app_enums.dart';

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

  factory DriverVehicle.fromJson(Map<String, dynamic> json) => DriverVehicle(
    id: json['id'] as String,
    driverId: json['driverId'] as String,
    type: json['type'] as String,
    model: json['model'] as String,
    plateNumber: json['plateNumber'] as String,
    plateType: json['plateType'] as String,
    color: json['color'] as String,
    seats: json['seats'] as int,
    isDefault: json['isDefault'] as bool,
    documentStatus: enumByName(
      DocumentStatus.values,
      json['documentStatus'],
      DocumentStatus.notUploaded,
    ),
    imagePath: json['imagePath'] as String?,
  );

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
