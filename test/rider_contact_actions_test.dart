import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/data/models/app_enums.dart';
import 'package:theraindriver/data/models/driver_trip.dart';
import 'package:theraindriver/features/rides/widgets/ride_common.dart';

void main() {
  final trip = DriverTrip(
    id: 'ride-1',
    driverId: 'driver-1',
    riderName: 'Test Rider',
    riderRating: 4.8,
    pickup: 'Pickup',
    dropOff: 'Drop off',
    fare: 1000,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.pending,
    status: TripStatus.accepted,
    rideType: 'classic',
    distanceKm: 5,
    durationMinutes: 12,
    createdAt: DateTime(2026),
    riderPhone: '+237670000000',
  );

  testWidgets('RiderCard hides contact actions before assignment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RiderCard(trip: trip)),
      ),
    );

    expect(find.byIcon(Icons.call_rounded), findsNothing);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
  });

  testWidgets('RiderCard shows call and message after assignment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RiderCard(trip: trip, showContact: true)),
      ),
    );

    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
  });
}
