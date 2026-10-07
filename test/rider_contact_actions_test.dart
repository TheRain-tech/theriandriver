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

  // The message icon opens the real, persisted, ride-scoped RideChatScreen (gated on the ride's
  // own id) - not an SMS handoff gated on the rider's phone number, which it regressed to once
  // and must not regress to again. RideChatScreen itself touches live Firestore on build, so this
  // only checks the enable/disable gating, never actually taps through to it.
  testWidgets(
    'RiderCard enables the message icon by ride id, not phone number',
    (tester) async {
      final noPhoneTrip = DriverTrip(
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
        riderPhone: '',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiderCard(trip: noPhoneTrip, showContact: true),
          ),
        ),
      );

      final messageButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chat_bubble_outline_rounded),
      );
      expect(messageButton.onPressed, isNotNull);

      final callButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.call_rounded),
      );
      expect(callButton.onPressed, isNull);
    },
  );

  testWidgets('RiderCard disables the message icon only when there is no ride id', (
    tester,
  ) async {
    final noIdTrip = DriverTrip(
      id: '',
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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RiderCard(trip: noIdTrip, showContact: true)),
      ),
    );

    final messageButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chat_bubble_outline_rounded),
    );
    expect(messageButton.onPressed, isNull);
  });
}
