import '../models/app_enums.dart';
import '../models/driver_verification.dart';

final mockDriverVerification = DriverVerification(
  id: 'verification-001',
  driverId: 'driver-001',
  status: DriverVerificationStatus.notStarted,
  nationalIdNumber: 'CM123456789',
  licenceNumber: 'DL-ABC123456',
  licenceExpiry: DateTime(2028, 12, 31),
);
