# AGENTS.md — theraindriver (Driver)

## Repository purpose

Driver Flutter application. Flutter-only — no embedded backend. Talks directly to Firebase (Auth, Firestore, Storage, Messaging) and to Firebase Cloud Functions callables.

## Canonical backend

The platform's canonical backend is `node-api` in the `therainAdmin` repository. **Phase 4 update**: this app now calls it — `lib/services/auth_sync_service.dart` posts to `POST /api/auth/sync` and reads `GET /api/drivers/me` on every sign-up/sign-in/Google-sign-in/cold-start, via the existing `lib/services/api_client.dart` (do not add a second HTTP client; every new node-api call should go through that class, constructor-injectable for tests the same way `DriverRevenueRepository`/`FleetRelationsRepository` already do). This sync is deliberately best-effort/non-blocking — the app's existing direct-Firestore `DriverRepository`/`DriverVerificationRepository` flow remains the primary, working path and was not replaced (see `therainAdmin/docs/platform/phase-4/DRIVER_AUTH_FLOW.md` and `PHASE_5_READINESS.md` for what a full migration would still require). This app's Cloud Functions callables (`sendWhatsAppOtp`, `createPayUnitPaymentSession`, `completeRideAndSettleEarnings`, `deductRideCommission`, `createWithdrawalRequest`, etc., region `africa-south1`) still have **no discoverable source in any of the four platform repositories** as of Phase 4 — see `therainAdmin/docs/platform/phase-4/CALLABLE_FUNCTIONS_MIGRATION.md`. Do not add new callable functions assuming a matching deployment exists until that is resolved.

## Canonical Firebase project

`therain-production` (already correctly configured in `.firebaserc`). Do not create another project. Do not run `flutterfire configure` without an explicit task asking for it.

## Identity authority

Firebase Authentication (client SDK — email/password, Google Sign-In) is already this app's only identity mechanism, and is the platform's sole identity authority. Phone verification here is a WhatsApp-OTP-via-Cloud-Functions flow, not Firebase Phone Auth — do not change this without checking `therainAdmin/docs/platform/IDENTITY_AND_AUTHORIZATION_CONTRACT.md` first.

## regionId requirement

**Phase 5 update**: a real region picker now exists (`lib/features/verification/screens/region_selection_screen.dart`, `lib/data/models/driver_taxonomy.dart#DriverTaxonomy.regions`), replacing the free-text `cityRegion` collection for new onboarding. Values match `therainAdmin/docs/platform/contracts/region-registry.json` exactly — do not add a second, locally-invented region list. `node-api` still validates/normalizes `regionId` server-side on every `POST /api/drivers/apply`/`PATCH /api/drivers/me/onboarding` call.

## Fleet membership (Phase 5)

`lib/data/repositories/fleet_membership_repository.dart` wraps the driver-facing fleetMemberships endpoints (`GET/POST /api/drivers/me/membership*`). `lib/features/verification/screens/fleet_join_screen.dart` (onboarding, affiliation=fleet only) and `membership_pending_screen.dart` (standalone, reachable any time) are the only UI surfaces that should ever touch these. A driver cannot activate their own membership, and this app never lets a driver type an arbitrary Fleet ID and have it silently trusted — `requestToJoin` is always server-validated. See `therainAdmin/docs/platform/DRIVER_AND_FLEET_CONTRACT.md` section 8.

## Central contract location

`therainAdmin/docs/platform/` is the source of truth. In particular, read `DRIVER_AND_FLEET_CONTRACT.md` before touching `driverType`/affiliation, vehicle type, or online-eligibility logic — this app currently conflates "vehicle type" with a service tier (`Classic`/`VIP`/`XL`/`Delivery`), which the platform contract treats as three separate concepts (`affiliationType`, `vehicleCategory`, `serviceTier`/`serviceTypes`); don't add new features that deepen that conflation.

## Repository-specific rules (binding)

- **Approval state must never be client-controlled.** `applicationStatus`, `kycStatus`/`verificationStatus`, and vehicle `approvalStatus` must only ever be written by the backend, never set directly by this app.
- **KYC and vehicle approval must never be self-approved.** There is no code path in this app that should ever set these to an approved value.
- **The client cannot directly set `canGoOnline`.** It is a computed/backend-owned eligibility flag (see `DRIVER_AND_FLEET_CONTRACT.md` §9) — this app's own existing online-eligibility check (`lib/data/repositories/driver_repository.dart:389-443`) is good practice to keep client-side as a UX gate, but it must never be treated as the enforcement point. **Phase 4 update**: `node-api`'s `PATCH /api/drivers/me/online` now hard-rejects `isOnline:true` server-side when the stored `canGoOnline` is false, independent of this app's own client-side check.
- **Never enable `ENABLE_MOCK_FALLBACK`/`ENABLE_PREVIEW_MODE` for a release build.** `lib/config/production_safety.dart#assertSafeForRelease()`, called at the very top of `main()`, throws and refuses to start if either flag is set in a release build — do not remove or bypass this call.
- **Driver affiliation, service type, and vehicle category must remain separate fields.** Do not reintroduce a single combined "vehicle type" concept when extending onboarding/profile screens.

## Security restrictions

- **Do not let `.env` be bundled as a Flutter asset.** It was removed from `pubspec.yaml`'s `flutter.assets` list during Phase 1 after backend secrets were found in this repo's local `.env` and a release APK built with the old asset declaration was confirmed shared outside this machine — see `therainAdmin/docs/platform/SECURITY_AND_PRIVACY_BASELINE.md` §2. Do not restore that asset line unless `.env` has first been stripped to contain only client-safe keys (Firebase client config, Maps key, feature flags) — never `JWT_SECRET`, `DATABASE_URL`, `PAYUNIT_*`, `WA_TOKEN`/`WA_APP_SECRET`, or any service-account reference.
- Never add a server secret (anything documented as "Secret" in `therainAdmin/docs/platform/CONFIGURATION_AND_ENVIRONMENT_MATRIX.md` §1) to this repository, in any file, tracked or not.
- Add a background FCM message handler (`onBackgroundMessage`) when touching notification code — currently missing.

## Required validation commands

```sh
flutter pub get
flutter analyze
flutter test
```

## Forbidden architectural changes

- Do not add a second authentication mechanism alongside Firebase Auth.
- Do not create a new Firestore collection duplicating an existing platform concept (e.g. a second "sos" or "wallet" collection) — check `therainAdmin/docs/platform/contracts/collection-registry.json` first; this app already has two such duplicates (`driver_locations` vs. canonical `driver_live_locations`, `sos_alerts` vs. canonical `sos_incidents`) that are migration targets, not a pattern to repeat.
