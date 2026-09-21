import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/data/repositories/fleet_membership_repository.dart';
import 'package:theraindriver/features/verification/screens/fleet_join_screen.dart';

class _FakeRepository extends FleetMembershipRepository {
  _FakeRepository({this.membership, this.fleets = const []});

  final Map<String, dynamic>? membership;
  final List<Map<String, dynamic>> fleets;

  @override
  Future<Map<String, dynamic>?> getMyMembership() async => membership;

  @override
  Future<List<Map<String, dynamic>>> listAvailableFleets() async => fleets;
}

Widget _host(Locale locale, FleetMembershipRepository repository) =>
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FleetJoinScreen(repository: repository),
    );

void main() {
  testWidgets(
    'a driver who is not invited sees the fleets of their region to choose from',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      await tester.pumpWidget(
        _host(
          const Locale('en'),
          _FakeRepository(
            fleets: [
              {'id': 'f-1', 'fleetName': 'Douala Express', 'town': 'Douala'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose your Fleet'), findsOneWidget);
      expect(find.text('Douala Express'), findsOneWidget);
      expect(find.text('Send Request'), findsOneWidget);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    },
  );

  testWidgets(
    'the driver\'s own request is "waiting for the Fleet Owner" - never an invitation they could accept',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      await tester.pumpWidget(
        _host(
          const Locale('en'),
          _FakeRepository(
            membership: {
              'id': 'm-1',
              'status': 'invited',
              'source': 'driver_request',
              'fleetName': 'Douala Express',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Your request to join Douala Express is waiting for the Fleet Owner to respond.',
        ),
        findsOneWidget,
      );
      expect(find.text('Accept Invitation'), findsNothing);
      expect(find.text('Cancel request'), findsOneWidget);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    },
  );

  testWidgets(
    'a real invitation from a fleet can be accepted, and the screen is in French for a French driver',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      await tester.pumpWidget(
        _host(
          const Locale('fr'),
          _FakeRepository(
            membership: {
              'id': 'm-2',
              'status': 'invited',
              'source': 'fleet_invitation',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Accepter l'invitation"), findsOneWidget);
      expect(
        find.text('Une invitation de flotte vous attend.'),
        findsOneWidget,
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
    },
  );
}
