import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/core/utils/account_status.dart';
import 'package:theraindriver/data/models/app_enums.dart';
import 'package:theraindriver/data/models/driver_profile.dart';

// Regression coverage for a real production bug: a genuinely-approved driver's
// drivers/{uid}.accountStatus can legitimately be "approved" (the older admin-approval flow's
// value) as well as "active" (driver.service.js#approve's current value) - node-api's own
// isAccountActive() treats both as equivalent. This client used to compare against the literal
// string "active" only, so any driver approved via the "approved" code path was permanently
// shown "Awaiting approval" and blocked from going online no matter what else was fixed.
// Reproduced live against a real production driver account.
void main() {
  test('isAccountStatusActive() accepts both "active" and "approved"', () {
    expect(isAccountStatusActive('active'), isTrue);
    expect(isAccountStatusActive('approved'), isTrue);
    expect(isAccountStatusActive('Active'), isTrue);
    expect(isAccountStatusActive('APPROVED'), isTrue);
  });

  test('isAccountStatusActive() rejects pending/rejected/suspended/null', () {
    expect(isAccountStatusActive('pending'), isFalse);
    expect(isAccountStatusActive('rejected'), isFalse);
    expect(isAccountStatusActive('suspended'), isFalse);
    expect(isAccountStatusActive(null), isFalse);
    expect(isAccountStatusActive(''), isFalse);
  });

  test(
    'DriverProfile.isAccountActive is true for a real approved-via-"approved" driver',
    () {
      // canGoOnline deliberately absent from this fixture - a server-computed cache field
      // this real driver's account predates. isAccountActive (used by the go-online
      // pre-checks) must not depend on it; isApprovedForRideOperations still requires it
      // (matching node-api's toggleOnline, which sets it fresh on every successful attempt -
      // by the time a driver is actually online, it is always populated).
      final profile = DriverProfile.fromMap({
        'uid': 'driver-1',
        'fullName': 'Real Driver',
        'accountStatus': 'approved',
        'verificationStatus': 'approved',
        'canReceiveRides': true,
      }, 'driver-1');

      expect(profile.isAccountActive, isTrue);
      expect(profile.verificationStatus, DriverVerificationStatus.approved);

      final onlineProfile = profile.copyWith(canGoOnline: true);
      expect(onlineProfile.isApprovedForRideOperations, isTrue);
    },
  );

  test(
    'DriverProfile.isAccountActive also recognizes rawStatus: "ACTIVE" as a second signal',
    () {
      final profile = DriverProfile.fromMap({
        'uid': 'driver-2',
        'fullName': 'Status-Only Driver',
        'accountStatus': 'pending',
        'status': 'ACTIVE',
      }, 'driver-2');

      expect(profile.isAccountActive, isTrue);
    },
  );

  test('DriverProfile.isAccountActive is false for a genuinely pending driver', () {
    final profile = DriverProfile.fromMap({
      'uid': 'driver-3',
      'fullName': 'Pending Driver',
      'accountStatus': 'pending',
    }, 'driver-3');

    expect(profile.isAccountActive, isFalse);
    expect(profile.isApprovedForRideOperations, isFalse);
  });
}
