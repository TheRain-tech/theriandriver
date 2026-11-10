import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/data/models/driver_profile.dart';
import 'package:theraindriver/data/repositories/driver_repository.dart';
import 'package:theraindriver/features/verification/screens/affiliation_selection_screen.dart';
import 'package:theraindriver/router/route_names.dart';
import 'package:theraindriver/services/auth_sync_service.dart';
import 'package:theraindriver/services/registration_draft_service.dart';

class _FakeDriverRepository extends DriverRepository {
  _FakeDriverRepository({this.profile});

  final DriverProfile? profile;

  @override
  Future<DriverProfile?> getProfile(String uid) async => profile;
}

class _FakeAuthSyncService extends AuthSyncService {
  _FakeAuthSyncService({this.error});

  final Object? error;
  bool wasCalled = false;

  @override
  Future<void> saveAffiliation({
    required String regionId,
    required String affiliationType,
  }) async {
    wasCalled = true;
    if (error != null) throw error!;
  }
}

DriverProfile _profile({
  String affiliationType = 'independent',
  String onboardingStep = 'profile_created',
  String onboardingStatus = 'in_progress',
  String applicationStatus = 'PENDING',
  DateTime? submittedAt,
}) => DriverProfile.fromMap({
  'uid': 'driver-1',
  'fullName': 'Test Driver',
  'verificationStatus': 'notStarted',
  'affiliationType': affiliationType,
  'onboardingStep': onboardingStep,
  'onboardingStatus': onboardingStatus,
  'applicationStatus': applicationStatus,
  'submittedAt': submittedAt,
}, 'driver-1');

Widget _host({
  required _FakeDriverRepository repository,
  required _FakeAuthSyncService syncService,
}) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: const [Locale('en'), Locale('fr')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: AffiliationSelectionScreen(
    driverRepository: repository,
    authSyncService: syncService,
    currentUserId: () => 'driver-1',
  ),
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => Scaffold(body: Text(settings.name ?? 'unknown')),
  ),
);

void main() {
  test('all backend submission markers lock the affiliation', () {
    expect(
      _profile(onboardingStep: 'submitted').hasSubmittedApplication,
      isTrue,
    );
    expect(
      _profile(applicationStatus: 'APPROVED').hasSubmittedApplication,
      isTrue,
    );
    expect(
      _profile(applicationStatus: 'REJECTED').hasSubmittedApplication,
      isTrue,
    );
    expect(
      _profile(submittedAt: DateTime(2026, 11, 7)).hasSubmittedApplication,
      isTrue,
    );
  });

  setUp(() {
    RegistrationDraftService.instance.clear();
    RegistrationDraftService.instance.updateRegion('southwest');
  });
  tearDown(RegistrationDraftService.instance.clear);

  testWidgets('only Independent Driver and Fleet Driver are offered', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        repository: _FakeDriverRepository(),
        syncService: _FakeAuthSyncService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Independent Driver'), findsOneWidget);
    expect(find.text('Fleet Driver'), findsOneWidget);
    expect(find.text('TheRain-managed Driver'), findsNothing);
  });

  testWidgets('a failed affiliation save keeps the driver on the choice screen', (
    tester,
  ) async {
    final syncService = _FakeAuthSyncService(error: StateError('offline'));
    await tester.pumpWidget(
      _host(repository: _FakeDriverRepository(), syncService: syncService),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fleet Driver'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(syncService.wasCalled, isTrue);
    expect(
      find.text(
        'We could not save your driver type. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text(RouteNames.region), findsNothing);
    expect(RegistrationDraftService.instance.value.affiliationType, isNull);
  });

  testWidgets('Fleet selection is saved before routing to region selection', (
    tester,
  ) async {
    final syncService = _FakeAuthSyncService();
    await tester.pumpWidget(
      _host(
        repository: _FakeDriverRepository(profile: _profile()),
        syncService: syncService,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fleet Driver'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(syncService.wasCalled, isTrue);
    expect(RegistrationDraftService.instance.value.affiliationType, 'fleet');
    expect(find.text(RouteNames.region), findsOneWidget);
  });

  testWidgets('Independent selection keeps the existing profile setup flow', (
    tester,
  ) async {
    final syncService = _FakeAuthSyncService();
    await tester.pumpWidget(
      _host(repository: _FakeDriverRepository(), syncService: syncService),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Independent Driver'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(syncService.wasCalled, isTrue);
    expect(
      RegistrationDraftService.instance.value.affiliationType,
      'independent',
    );
    expect(find.text(RouteNames.profileSetup), findsOneWidget);
  });

  testWidgets('a submitted application cannot change affiliation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        repository: _FakeDriverRepository(
          profile: _profile(
            onboardingStep: 'submitted',
            onboardingStatus: 'submitted',
          ),
        ),
        syncService: _FakeAuthSyncService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Independent Driver'), findsNothing);
    expect(find.text('Fleet Driver'), findsNothing);
    expect(
      find.text(
        'Your application has already been submitted or approved. Your driver type can no longer be changed.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('an approved application cannot change affiliation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        repository: _FakeDriverRepository(
          profile: _profile(
            onboardingStep: 'review',
            onboardingStatus: 'in_progress',
            applicationStatus: 'APPROVED',
          ),
        ),
        syncService: _FakeAuthSyncService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Independent Driver'), findsNothing);
    expect(find.text('Fleet Driver'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
