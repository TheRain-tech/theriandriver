import '../models/app_enums.dart';
import '../models/driver_profile.dart';

final mockDriverProfile = DriverProfile(
  id: 'driver-001',
  fullName: 'John Driver',
  phone: '+237 6XX XXX XXX',
  email: 'johndriver@email.com',
  rating: 4.8,
  totalTrips: 230,
  onlineStatus: DriverOnlineStatus.online,
  verificationStatus: DriverVerificationStatus.notStarted,
  vehicleId: 'vehicle-001',
  memberSince: DateTime(2024, 5),
);
