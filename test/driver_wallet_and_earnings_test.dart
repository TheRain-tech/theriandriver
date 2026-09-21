import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/core/localization/driver_copy.dart';
import 'package:theraindriver/data/models/app_enums.dart';
import 'package:theraindriver/data/models/commission_wallet.dart';
import 'package:theraindriver/data/models/driver_profile.dart';
import 'package:theraindriver/data/models/driver_trip.dart';
import 'package:theraindriver/data/models/driver_wallet_requirement.dart';
import 'package:theraindriver/features/shared/widgets/trip_earnings_card.dart';

DriverProfile _profile({
  String? affiliationType,
  String driverType = 'individual',
  String? fleetId,
  String? currentFleetId,
}) => DriverProfile(
  id: 'driver-1',
  fullName: 'Test Driver',
  phone: '',
  email: '',
  rating: 0,
  totalTrips: 0,
  onlineStatus: DriverOnlineStatus.offline,
  verificationStatus: DriverVerificationStatus.approved,
  affiliationType: affiliationType,
  driverType: driverType,
  fleetId: fleetId,
  currentFleetId: currentFleetId,
);

Widget _host(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('fr')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

DriverTrip _trip(Map<String, dynamic> extra) => DriverTrip.fromMap({
  'rideId': 'ride-1',
  'driverId': 'driver-1',
  'status': 'completed',
  'estimatedFare': 2000,
  'platformCommissionPercentage': 25,
  ...extra,
}, 'ride-1');

void main() {
  group('who needs a wallet (display of the server\'s rule)', () {
    test('a fleet driver is a fleet driver whatever else is stored', () {
      expect(
        walletCategoryOf(_profile(affiliationType: 'fleet')),
        DriverWalletCategory.fleet,
      );
      expect(
        walletCategoryOf(
          _profile(affiliationType: 'independent', currentFleetId: 'f-1'),
        ),
        DriverWalletCategory.fleet,
      );
    });

    test('a TheRain-managed driver needs no wallet', () {
      expect(
        walletCategoryOf(_profile(affiliationType: 'therain_managed')),
        DriverWalletCategory.therainManaged,
      );
      expect(
        walletCategoryOf(_profile(driverType: 'company')),
        DriverWalletCategory.therainManaged,
      );
    });

    test(
      'anyone else is an own-vehicle driver, so nobody dodges the wallet',
      () {
        expect(
          walletCategoryOf(_profile(affiliationType: 'independent')),
          DriverWalletCategory.ownVehicle,
        );
        expect(walletCategoryOf(_profile()), DriverWalletCategory.ownVehicle);
      },
    );
  });

  group('blocks are explained in the driver\'s language', () {
    test('own-vehicle: what is missing, with the server\'s figures', () {
      final requirement = DriverWalletRequirement.fromJson({
        'category': 'own_vehicle',
        'required': true,
        'minimumBalance': 10000,
        'balance': 2500,
        'canGoOnline': false,
        'code': 'DRIVER_WALLET_INSUFFICIENT',
      });
      final en = requirement.blockMessage()!;
      expect(en, contains('2,500 XAF'));
      expect(en, contains('10,000 XAF'));
      expect(en, contains('Top up at least 7,500 XAF'));
    });

    test('fleet: tells the driver to ask the Fleet Owner, not to top up', () {
      final message = walletBlockMessage(
        'FLEET_WALLET_INSUFFICIENT',
        minimumBalance: 10000,
      )!;
      expect(message, contains('Fleet Owner'));
      expect(message, contains('10,000 XAF'));
      expect(message.toLowerCase(), isNot(contains('top up your')));
    });

    test('without the server\'s figure no amount is invented', () {
      final message = walletBlockMessage('DRIVER_WALLET_INSUFFICIENT')!;
      expect(message, isNot(contains('0 XAF')));
      expect(message, contains('required minimum'));
    });

    test('every wallet block has a message; other codes fall through', () {
      for (final code in walletBlockCodes) {
        expect(walletBlockMessage(code, minimumBalance: 10000), isNotNull);
      }
      expect(walletBlockMessage('SOMETHING_ELSE'), isNull);
      expect(walletBlockMessage(null), isNull);
    });

    testWidgets('in French', (tester) async {
      late DriverCopy copy;
      await tester.pumpWidget(
        _host(
          const Locale('fr'),
          Builder(
            builder: (context) {
              copy = DriverCopy.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      final message = walletBlockMessage(
        'DRIVER_WALLET_INSUFFICIENT',
        minimumBalance: 10000,
        balance: 2500,
        copy: copy,
      )!;
      expect(message, contains('portefeuille TheRain'));
      expect(message, contains('Rechargez au moins 7,500 XAF'));
      expect(
        walletBlockMessage('FLEET_WALLET_INSUFFICIENT', copy: copy),
        contains('propriétaire de flotte'),
      );
    });
  });

  group('the commission wallet takes the minimum from the server', () {
    test(
      'the summary carries the minimum that decides "ready to receive rides"',
      () {
        final short = CommissionWallet.fromSummary({
          'driverId': 'driver-1',
          'balance': 9000,
          'status': 'ACTIVE',
          'minimumBalance': 10000,
        });
        expect(short.minimumRequiredBalance, 10000);
        expect(short.canReceiveRides, isFalse);
        final funded = CommissionWallet.fromSummary({
          'driverId': 'driver-1',
          'balance': 10000,
          'status': 'ACTIVE',
          'minimumBalance': 10000,
        });
        expect(funded.canReceiveRides, isTrue);
      },
    );

    test(
      'an older backend that sends no minimum keeps the previous behaviour',
      () {
        final wallet = CommissionWallet.fromSummary({
          'driverId': 'driver-1',
          'balance': 1,
          'status': 'ACTIVE',
        });
        expect(wallet.minimumRequiredBalance, 1);
        expect(wallet.canReceiveRides, isTrue);
      },
    );
  });

  group('the trip fare, commission and earnings are the stored ones', () {
    test('the acceptance-time placeholder percentage is never used', () {
      final trip = _trip({});
      expect(trip.commissionRatePercent, isNull);
      expect(trip.commissionAmount, isNull);
      expect(trip.driverEarnings, isNull);
      // even a leftover amount is ignored until the server has stamped the snapshot
      final unstamped = _trip({'commissionAmount': 500, 'netAmount': 1500});
      expect(unstamped.commissionAmount, isNull);
    });

    test(
      'once stamped, the fare, rate, commission and earnings come from the ride',
      () {
        final trip = _trip({
          'financialSnapshotAt': '2026-06-12T12:30:00Z',
          'finalFareAmount': 3000,
          'commissionRatePercent': 15,
          'commissionAmount': 450,
          'netAmount': 2550,
        });
        expect(trip.fare, 3000);
        expect(trip.commissionRatePercent, 15);
        expect(trip.commissionAmount, 450);
        expect(trip.driverEarnings, 2550);
      },
    );

    testWidgets(
      'the card shows Trip Fare / TheRain Commission 15% / Your Earnings',
      (tester) async {
        final trip = _trip({
          'financialSnapshotAt': '2026-06-12T12:30:00Z',
          'finalFareAmount': 3000,
          'commissionRatePercent': 15,
          'commissionAmount': 450,
          'netAmount': 2550,
        });
        await tester.pumpWidget(
          _host(const Locale('en'), TripEarningsCard(trip: trip)),
        );
        expect(find.text('Trip Fare'), findsOneWidget);
        expect(find.text('3,000 XAF'), findsOneWidget);
        expect(find.text('TheRain Commission 15%'), findsOneWidget);
        expect(find.text('- 450 XAF'), findsOneWidget);
        expect(find.text('Your Earnings'), findsOneWidget);
        expect(find.text('2,550 XAF'), findsOneWidget);
      },
    );

    testWidgets('a rate set to 12.5% in the dashboard is shown as 12.5%', (
      tester,
    ) async {
      final trip = _trip({
        'financialSnapshotAt': '2026-06-12T12:30:00Z',
        'finalFareAmount': 3000,
        'commissionRatePercent': 12.5,
        'commissionAmount': 375,
        'netAmount': 2625,
      });
      await tester.pumpWidget(
        _host(const Locale('fr'), TripEarningsCard(trip: trip)),
      );
      expect(find.text('Commission TheRain 12.5 %'), findsOneWidget);
      expect(find.text('Vos gains'), findsOneWidget);
      expect(find.text('Tarif de la course'), findsOneWidget);
    });

    testWidgets(
      'before the server has stored the commission only the fare is shown - nothing invented',
      (tester) async {
        await tester.pumpWidget(
          _host(const Locale('en'), TripEarningsCard(trip: _trip({}))),
        );
        expect(find.text('Trip Fare'), findsOneWidget);
        expect(find.textContaining('%'), findsNothing);
        expect(find.text('Your Earnings'), findsNothing);
        expect(
          find.textContaining('as soon as the trip is settled'),
          findsOneWidget,
        );
      },
    );
  });
}
