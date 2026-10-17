import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/data/models/driver_trip.dart';
import 'package:theraindriver/data/models/ride_request.dart';

void main() {
  group('RideRequest.fromMap group-ride/passenger fields', () {
    test('defaults to just_me/1 passenger when absent (older requests)', () {
      final request = RideRequest.fromMap({
        'riderId': 'rider-1',
        'riderName': 'Jane',
        'riderPhone': '+237600000000',
      }, 'req-1');
      expect(request.isGroupRide, isFalse);
      expect(request.groupRideType, 'just_me');
      expect(request.passengerCount, 1);
      expect(request.passengers, isEmpty);
    });

    test('parses a real group-ride request with multiple passengers', () {
      final request = RideRequest.fromMap({
        'riderId': 'rider-1',
        'riderName': 'Jane',
        'isGroupRide': true,
        'groupRideType': 'me_and_friends',
        'passengerCount': 3,
        'passengers': [
          {'name': 'Aisha Nguim', 'phoneNumber': '+237612345678'},
          {'name': 'John Mbi', 'phoneNumber': '+237698765432'},
        ],
      }, 'req-2');
      expect(request.isGroupRide, isTrue);
      expect(request.groupRideType, 'me_and_friends');
      expect(request.passengerCount, 3);
      expect(request.passengers, hasLength(2));
      expect(request.passengers[0].name, 'Aisha Nguim');
      expect(request.passengers[0].phoneNumber, '+237612345678');
      expect(request.passengers[1].name, 'John Mbi');
    });

    test('ignores non-map entries in a malformed passengers list instead of throwing', () {
      final request = RideRequest.fromMap({
        'riderId': 'rider-1',
        'isGroupRide': true,
        'passengers': ['not a map', 42, null],
      }, 'req-3');
      expect(request.passengers, isEmpty);
    });
  });

  group('DriverTrip.fromMap group-ride/passenger fields', () {
    test('defaults to just_me/1 passenger when absent (a ride accepted before this fix)', () {
      final trip = DriverTrip.fromMap({'driverId': 'driver-1'}, 'ride-1');
      expect(trip.isGroupRide, isFalse);
      expect(trip.groupRideType, 'just_me');
      expect(trip.passengerCount, 1);
      expect(trip.passengers, isEmpty);
    });

    test('parses the group-ride fields the Cloud Function now copies onto the ride doc', () {
      final trip = DriverTrip.fromMap({
        'driverId': 'driver-1',
        'isGroupRide': true,
        'groupRideType': 'someone_else',
        'passengerCount': 1,
        'passengers': [
          {'name': 'Sarah Lobe', 'phoneNumber': '+237655667788'},
        ],
      }, 'ride-2');
      expect(trip.isGroupRide, isTrue);
      expect(trip.groupRideType, 'someone_else');
      expect(trip.passengers, hasLength(1));
      expect(trip.passengers.single.name, 'Sarah Lobe');
    });
  });
}
