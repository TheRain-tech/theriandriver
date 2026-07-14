# AGENTS.md — theraindriver (Driver)

## Repository purpose

Driver Flutter application. Flutter-only — no embedded backend. Talks directly to Firebase (Auth, Firestore, Storage, Messaging) and to Firebase Cloud Functions callables.

## Canonical backend

The platform's canonical backend is `node-api` in the `therainAdmin` repository. This app currently does **not** call it — `API_BASE_URL` is configured (`lib/config/env_config.dart`) but has zero call sites. This app's Cloud Functions callables (`sendWhatsAppOtp`, `createPayUnitPaymentSession`, `completeRideAndSettleEarnings`, `deductRideCommission`, `createWithdrawalRequest`, etc., region `africa-south1`) have **no discoverable source in any of the four platform repositories** as of Phase 1 — see `therainAdmin/docs/platform/CURRENT_STATE_AUDIT.md` "Unknowns requiring investigation." Do not add new callable functions assuming a matching deployment exists until that is resolved.

## Canonical Firebase project

`therain-production` (already correctly configured in `.firebaserc`). Do not create another project. Do not run `flutterfire configure` without an explicit task asking for it.

## Identity authority

Firebase Authentication (client SDK — email/password, Google Sign-In) is already this app's only identity mechanism, and is the platform's sole identity authority. Phone verification here is a WhatsApp-OTP-via-Cloud-Functions flow, not Firebase Phone Auth — do not change this without checking `therainAdmin/docs/platform/IDENTITY_AND_AUTHORIZATION_CONTRACT.md` first.

## regionId requirement

This app has no region enum or validation today — `cityRegion` is a free-text field, and ride documents carry a `regionId` this app receives opaquely and never re-derives. Do not add a second, locally-invented region list; use `therainAdmin/docs/platform/contracts/region-registry.json` as the canonical set if a region picker is ever needed here.

## Central contract location

`therainAdmin/docs/platform/` is the source of truth. In particular, read `DRIVER_AND_FLEET_CONTRACT.md` before touching `driverType`/affiliation, vehicle type, or online-eligibility logic — this app currently conflates "vehicle type" with a service tier (`Classic`/`VIP`/`XL`/`Delivery`), which the platform contract treats as three separate concepts (`affiliationType`, `vehicleCategory`, `serviceTier`/`serviceTypes`); don't add new features that deepen that conflation.

## Repository-specific rules (binding)

- **Approval state must never be client-controlled.** `applicationStatus`, `kycStatus`/`verificationStatus`, and vehicle `approvalStatus` must only ever be written by the backend, never set directly by this app.
- **KYC and vehicle approval must never be self-approved.** There is no code path in this app that should ever set these to an approved value.
- **The client cannot directly set `canGoOnline`.** It is a computed/backend-owned eligibility flag (see `DRIVER_AND_FLEET_CONTRACT.md` §9) — this app's own existing online-eligibility check (`lib/data/repositories/driver_repository.dart:389-443`) is good practice to keep client-side as a UX gate, but it must never be treated as the enforcement point; the backend recomputes it independently.
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
