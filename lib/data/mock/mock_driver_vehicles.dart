import '../models/app_enums.dart';
import '../models/driver_vehicle.dart';

const mockDriverVehicles = <DriverVehicle>[
  DriverVehicle(
    id: 'vehicle-001',
    driverId: 'driver-001',
    type: 'Classic',
    model: 'Toyota Camry 2020',
    plateNumber: 'ABC 123 CD',
    plateType: 'Private',
    color: 'Black',
    seats: 4,
    isDefault: true,
    documentStatus: DocumentStatus.verified,
  ),
  DriverVehicle(
    id: 'vehicle-002',
    driverId: 'driver-001',
    type: 'Classic',
    model: 'Toyota Corolla 2018',
    plateNumber: 'XYZ 987 AB',
    plateType: 'Private',
    color: 'White',
    seats: 4,
    isDefault: false,
    documentStatus: DocumentStatus.pending,
  ),
];
