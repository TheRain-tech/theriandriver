import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/data/models/app_enums.dart';
import 'package:theraindriver/data/models/driver_profile.dart';

void main() {
  test(
    'DriverProfile.fromMap parses Phase 4 canonical taxonomy fields from node-api',
    () {
      final profile = DriverProfile.fromMap({
        'uid': 'driver-1',
        'fullName': 'Test Driver',
        'affiliationType': 'fleet',
        'serviceTypes': ['ride_hailing', 'delivery'],
        'vehicleCategory': 'van',
        'currentFleetId': 'fleet-42',
        'currentVehicleId': 'vehicle-7',
        'kycStatus': 'approved',
        'applicationStatus': 'APPROVED',
      }, 'driver-1');

      expect(profile.affiliationType, 'fleet');
      expect(profile.serviceTypes, ['ride_hailing', 'delivery']);
      expect(profile.vehicleCategory, 'van');
      expect(profile.currentFleetId, 'fleet-42');
      expect(profile.currentVehicleId, 'vehicle-7');
      expect(profile.kycStatus, 'approved');
      expect(profile.applicationStatus, 'APPROVED');
    },
  );

  test(
    'DriverProfile.fromMap falls back to legacy fields when canonical ones are absent',
    () {
      final profile = DriverProfile.fromMap({
        'uid': 'driver-2',
        'fullName': 'Legacy Driver',
        'fleetId': 'legacy-fleet-1',
        'vehicleId': 'legacy-vehicle-1',
        'verificationStatus': 'pending',
      }, 'driver-2');

      expect(profile.currentFleetId, 'legacy-fleet-1');
      expect(profile.currentVehicleId, 'legacy-vehicle-1');
      expect(profile.kycStatus, 'pending');
      // A record that predates Phase 4 has no canonical taxonomy yet - these must stay null/empty
      // rather than a guessed default, matching node-api's own "never guess" contract.
      expect(profile.affiliationType, isNull);
      expect(profile.serviceTypes, isEmpty);
      expect(profile.vehicleCategory, isNull);
    },
  );

  test('DriverProfile.toJson round-trips the new canonical fields', () {
    final profile = DriverProfile(
      id: 'driver-3',
      fullName: 'Round Trip',
      phone: '',
      email: '',
      rating: 0,
      totalTrips: 0,
      onlineStatus: DriverOnlineStatus.offline,
      verificationStatus: DriverVerificationStatus.notStarted,
      affiliationType: 'independent',
      serviceTypes: ['ride_hailing'],
      vehicleCategory: 'car',
    );

    final json = profile.toJson();
    expect(json['affiliationType'], 'independent');
    expect(json['serviceTypes'], ['ride_hailing']);
    expect(json['vehicleCategory'], 'car');
  });
}
