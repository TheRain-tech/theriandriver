import '../models/app_enums.dart';
import '../models/driver_document.dart';

final mockDriverDocuments = <DriverDocument>[
  DriverDocument(
    id: 'doc-001',
    driverId: 'driver-001',
    vehicleId: 'vehicle-001',
    type: 'Insurance',
    status: DocumentStatus.verified,
    expiresAt: DateTime(2026, 10, 20),
  ),
  DriverDocument(
    id: 'doc-002',
    driverId: 'driver-001',
    vehicleId: 'vehicle-001',
    type: 'Road Licence',
    status: DocumentStatus.verified,
    expiresAt: DateTime(2026, 1, 15),
  ),
  DriverDocument(
    id: 'doc-003',
    driverId: 'driver-001',
    vehicleId: 'vehicle-001',
    type: 'Fitness Certificate',
    status: DocumentStatus.pending,
    expiresAt: DateTime(2026, 12, 31),
  ),
  const DriverDocument(
    id: 'doc-004',
    driverId: 'driver-001',
    vehicleId: 'vehicle-001',
    type: 'Vehicle Photos',
    status: DocumentStatus.uploaded,
  ),
];
