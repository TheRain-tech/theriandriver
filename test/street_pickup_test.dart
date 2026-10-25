import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/data/models/driver_trip.dart';
import 'package:theraindriver/data/models/street_pickup_quote.dart';
import 'package:theraindriver/data/repositories/street_pickup_repository.dart';
import 'package:theraindriver/features/rides/street_pickup/street_pickup_share.dart';

void main() {
  group('StreetPickupQuote.fromApi', () {
    test('reads node-api estimateFare fields', () {
      // Shape of node-api utils/fare.js#estimateFare + ride.service.js#buildFareEstimate.
      final quote = StreetPickupQuote.fromApi({
        'total': 2350,
        'currency': 'XAF',
        'distanceKm': 7.46,
        'distanceMeters': 7460,
        'durationSeconds': 1130,
        'encodedPolyline': 'abc',
        'regionId': 'littoral-douala',
      });
      expect(quote.fare, 2350);
      expect(quote.currency, 'XAF');
      expect(quote.distanceKm, 7.5);
      expect(quote.durationMinutes, 19);
      expect(quote.routePolyline, 'abc');
      expect(quote.regionId, 'littoral-douala');
    });

    test('falls back to distanceMeters when distanceKm is absent', () {
      final quote = StreetPickupQuote.fromApi({
        'total': 1000,
        'distanceMeters': 2500,
      });
      expect(quote.distanceKm, 2.5);
      expect(quote.currency, 'XAF');
      expect(quote.durationMinutes, 0);
    });
  });

  test('ride types map to node-api pricing like the rider app', () {
    expect(StreetPickupRepository.nodeApiRideType('classic'), 'standard');
    expect(StreetPickupRepository.nodeApiRideType('comfort'), 'standard');
    expect(StreetPickupRepository.nodeApiRideType('vip'), 'premium');
  });

  test('passenger numbers are normalised for wa.me / sms links', () {
    expect(
      StreetPickupShare.internationalDigits('+237 6 77 12 34 56'),
      '237677123456',
    );
    expect(
      StreetPickupShare.internationalDigits('677 123 456'),
      '237677123456',
    );
    expect(
      StreetPickupShare.internationalDigits('00237677123456'),
      '237677123456',
    );
  });

  test('Plus Codes are recognised and stripped from shared addresses', () {
    expect(StreetPickupRepository.isPlusCode('X552+V8H'), isTrue);
    expect(StreetPickupRepository.isPlusCode('252M+5V Bamenda'), isTrue);
    expect(StreetPickupRepository.isPlusCode('Mile 4 Park, Bamenda'), isFalse);
    expect(StreetPickupRepository.isPlusCode('Akwa, Douala'), isFalse);
    expect(
      StreetPickupRepository.withoutPlusCode('X552+V8H, Douala, Cameroon'),
      'Douala, Cameroon',
    );
    expect(
      StreetPickupRepository.withoutPlusCode('252M+5V Bamenda'),
      'Bamenda',
    );
    expect(
      StreetPickupRepository.withoutPlusCode('Akwa, Douala'),
      'Akwa, Douala',
    );
  });

  test('a street pickup ride doc is recognised as one', () {
    final trip = DriverTrip.fromMap({
      'rideId': 'r1',
      'driverId': 'd1',
      'status': 'in_progress',
      'source': 'street_pickup',
      'isStreetPickup': true,
      'riderId': null,
      'riderName': null,
      'riderPhone': '677123456',
      'estimatedFare': 1500,
      'paymentMethod': 'cash',
    }, 'r1');
    expect(trip.isStreetPickup, isTrue);
    expect(trip.riderPhone, '677123456');
    expect(trip.fare, 1500);

    final booked = DriverTrip.fromMap({
      'rideId': 'r2',
      'status': 'in_progress',
    }, 'r2');
    expect(booked.isStreetPickup, isFalse);
  });
}
