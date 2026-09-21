import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/features/auth/screens/claim_invitation_screen.dart';
import 'package:theraindriver/services/deep_link_service.dart';

const _token =
    'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

Widget _host(Locale locale, Widget child, {Object? arguments}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('fr')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  onGenerateRoute: (settings) => MaterialPageRoute(
    settings: RouteSettings(name: settings.name, arguments: arguments),
    builder: (_) => child,
  ),
);

void main() {
  group('the invitation token inside a tapped link', () {
    test('the shared https link', () {
      expect(
        fleetInviteTokenFrom(
          Uri.parse('https://app.therain.app/fleet-invite?token=$_token'),
        ),
        _token,
      );
    });

    test('the app\'s own scheme (both forms)', () {
      expect(
        fleetInviteTokenFrom(
          Uri.parse('therain-driver://app/fleet-invite?token=$_token'),
        ),
        _token,
      );
      expect(
        fleetInviteTokenFrom(
          Uri.parse('therain-driver://fleet-invite?token=$_token'),
        ),
        _token,
      );
    });

    test(
      'anything else is ignored - other paths, schemes and malformed codes',
      () {
        expect(
          fleetInviteTokenFrom(
            Uri.parse('https://app.therain.app/other?token=$_token'),
          ),
          isNull,
        );
        expect(
          fleetInviteTokenFrom(
            Uri.parse('ftp://app.therain.app/fleet-invite?token=$_token'),
          ),
          isNull,
        );
        expect(
          fleetInviteTokenFrom(
            Uri.parse('https://app.therain.app/fleet-invite'),
          ),
          isNull,
        );
        expect(
          fleetInviteTokenFrom(
            Uri.parse('https://app.therain.app/fleet-invite?token=short'),
          ),
          isNull,
        );
        expect(
          fleetInviteTokenFrom(
            Uri.parse(
              'https://app.therain.app/fleet-invite?token=<script>alert(1)</script>xxxxxxxx',
            ),
          ),
          isNull,
        );
      },
    );
  });

  group('the claim screen', () {
    testWidgets('opened from a link it already holds the code', (tester) async {
      await tester.pumpWidget(
        _host(
          const Locale('en'),
          const ClaimInvitationScreen(),
          arguments: {'token': _token},
        ),
      );
      await tester.pump();
      expect(find.text(_token), findsOneWidget);
      // drain the (unconfigured-server) check the screen started on its own
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets('opened by hand it starts empty', (tester) async {
      await tester.pumpWidget(
        _host(const Locale('en'), const ClaimInvitationScreen()),
      );
      await tester.pump();
      expect(find.text('Join Your Fleet'), findsOneWidget);
      expect(find.text('Check Invitation'), findsOneWidget);
    });

    testWidgets('is in French', (tester) async {
      await tester.pumpWidget(
        _host(const Locale('fr'), const ClaimInvitationScreen()),
      );
      await tester.pump();
      expect(find.text('Rejoignez votre flotte'), findsOneWidget);
      expect(find.text("Vérifier l'invitation"), findsOneWidget);
    });

    testWidgets(
      'the verified invitation shows fleet, region, status and expiry - "You\'re invited to join"',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const Locale('en'),
            const Scaffold(
              body: InvitationPreviewCard(
                preview: {
                  'fleetName': 'Douala Express',
                  'regionName': 'Littoral',
                  'status': 'invited',
                  'expiresAt': '2030-01-15T00:00:00.000Z',
                },
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text("You're joining Douala Express"), findsOneWidget);
        expect(find.text('Littoral'), findsOneWidget);
        expect(find.text('Invitation valid'), findsOneWidget);
        expect(find.text('Code valid until 15/1/2030'), findsOneWidget);
        // no logo stored -> the fleet's initial, never a broken image
        expect(find.text('D'), findsOneWidget);
      },
    );

    testWidgets('and in French', (tester) async {
      await tester.pumpWidget(
        _host(
          const Locale('fr'),
          const Scaffold(
            body: InvitationPreviewCard(
              preview: {
                'fleetName': 'Douala Express',
                'city': 'Douala',
                'status': 'invited',
                'expiresAt': '2030-01-15T00:00:00.000Z',
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Vous rejoignez Douala Express'), findsOneWidget);
      expect(find.text('Invitation valide'), findsOneWidget);
      expect(find.text("Code valable jusqu'au 15/1/2030"), findsOneWidget);
    });
  });
}
