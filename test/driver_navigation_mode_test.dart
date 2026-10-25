import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/data/models/app_enums.dart';
import 'package:theraindriver/data/models/driver_profile.dart';
import 'package:theraindriver/data/models/fleet_info.dart';
import 'package:theraindriver/features/shared/driver_navigation_mode.dart';

void main() {
  const fleetDriver = DriverProfile(
    id: 'driver-1',
    fullName: 'Fleet Driver',
    phone: '',
    email: '',
    rating: 0,
    totalTrips: 0,
    onlineStatus: DriverOnlineStatus.offline,
    verificationStatus: DriverVerificationStatus.approved,
    currentFleetId: 'fleet-1',
  );
  const legacyFleetProfile = DriverProfile(
    id: 'legacy-driver',
    fullName: 'Legacy Driver',
    phone: '',
    email: '',
    rating: 0,
    totalTrips: 0,
    onlineStatus: DriverOnlineStatus.offline,
    verificationStatus: DriverVerificationStatus.approved,
    fleetId: 'fleet-1',
  );

  FleetInfo fleet({
    String id = 'fleet-1',
    String status = 'approved',
    String? approvalStatus = 'approved',
  }) => FleetInfo(
    id: id,
    fleetName: 'Fleet',
    companyName: 'Fleet',
    status: status,
    approvalStatus: approvalStatus,
  );

  test('fleet navigation requires matching approved fleet information', () {
    expect(isConfirmedFleetDriver(fleetDriver, fleet()), isTrue);
    expect(
      isConfirmedFleetDriver(
        fleetDriver,
        fleet(status: 'pending', approvalStatus: 'approved'),
      ),
      isFalse,
    );
    expect(
      isConfirmedFleetDriver(
        fleetDriver,
        fleet(status: 'approved', approvalStatus: 'pending'),
      ),
      isFalse,
    );
    expect(
      isConfirmedFleetDriver(fleetDriver, fleet(id: 'other-fleet')),
      isFalse,
    );
    expect(isConfirmedFleetDriver(fleetDriver, null), isFalse);
    expect(isConfirmedFleetDriver(legacyFleetProfile, fleet()), isFalse);
  });

  test('independent and pending drivers are not confirmed fleet drivers', () {
    const independentDriver = DriverProfile(
      id: 'driver-2',
      fullName: 'Independent Driver',
      phone: '',
      email: '',
      rating: 0,
      totalTrips: 0,
      onlineStatus: DriverOnlineStatus.offline,
      verificationStatus: DriverVerificationStatus.approved,
    );
    expect(isConfirmedFleetDriver(independentDriver, fleet()), isFalse);

    expect(
      isConfirmedFleetDriver(
        fleetDriver,
        fleet(status: 'PENDING', approvalStatus: 'pending'),
      ),
      isFalse,
    );
  });
}
