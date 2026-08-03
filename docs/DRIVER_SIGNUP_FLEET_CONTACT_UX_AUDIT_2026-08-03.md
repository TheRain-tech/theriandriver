# Driver Signup, Fleet, and Contact UX Audit

Date: 2026-08-03  
App: TheRain Driver  
Package: `com.therain.driver`  
Firebase project: `therain-production`

## 1. Outcome

The driver account flow is now account-first, resumable, and explicit about approval. Creating an account no longer drops the driver directly into a long form with duplicate identity fields. It opens an application home that shows four meaningful sections, current progress, the driver's vehicle/payment relationship, identity documents, and fleet relationship.

TheRain still requires administrator approval of the driver application, KYC documents, and vehicle before online access or ride reception. No client approval field or go-online security gate was weakened.

The post-signup experience now opens the restricted Driver dashboard immediately. Until verification is approved, the dashboard and Notifications screen keep a profile-completion reminder visible, the Go Online button is disabled, and the app does not subscribe the driver to incoming ride requests.

This follows the useful part of the Yango-style pattern: a short account form, document/photo onboarding, and activation only after verification. Official references reviewed:

- https://yango.com/en/driver/
- https://yango.com/en_ao/driver/

## 2. Root Causes Found

| Area | Previous issue | Root cause |
| --- | --- | --- |
| Signup | The account form felt like the start of an unending tunnel. | Account creation routed directly into a long profile, vehicle, city, and payout form. |
| Profile | Name, phone, and email were requested again immediately after signup. | `driver_profile_setup_screen.dart` mixed immutable account identity with vehicle and payout setup. |
| Resume | Incomplete drivers resumed at whichever low-level KYC screen `onboardingStep` named. | There was no application home or checklist that rebuilt state from Firestore. |
| Review | The review page showed 16 repetitive edit rows. | Account, work mode, vehicle, payment, and documents were flattened into one list. |
| Pending | A submitted driver could only wait, contact support, or sign out. | The pending screen did not show the driver-to-document or driver-to-fleet relationship. |
| Fleet identity | Some records used `fleetId`; canonical records use `currentFleetId`. | Fleet checks preferred only the legacy field in parts of the app. |
| Fleet onboarding | A driver who selected Fleet could continue without an invitation or join request. | The Fleet screen's Continue action was always enabled. |
| Contact timing | The pre-accept ride request card displayed a call action. | `RiderCard` always rendered Call and only gated Message. |
| Contact persistence | Contact could disappear after restart during an assigned ride. | The accepted `rides/{rideId}` document did not copy `riderName` or `riderPhone` from the request. |
| Profile save | Account creation could end with "We could not save your driver profile." | `seedDriverProfile` reads missing `driver_verifications/{uid}` inside a transaction before creating it, but the read rule depended only on `resource.data.driverId`. A missing document has no `resource.data`, so Firestore denied the read and aborted the transaction. |
| Pending account access | Incomplete drivers were forced back into onboarding/pending screens. | Auth routing and route guards treated verification as an app-access gate instead of only a ride-operation gate. |

## 3. Changes Applied

### Account and application home

- `lib/features/auth/screens/signup_screen.dart`
  - Kept the form to name, phone, email, password, and terms.
  - Added a password visibility control and autofill hints.
  - Corrected the terms copy: the account is created immediately, while work access waits for verification.
  - Changed the primary action to `Create account`.
- `lib/features/verification/screens/driver_application_screen.dart`
  - Added a resumable application home with a 4-section progress indicator.
  - Hydrates saved profile, payout, taxonomy, and KYC paths from Firestore.
  - Shows Account, Vehicle and payment, How you will drive, and Identity documents.
  - Shows the driver's direct/TheRain-managed/Fleet relationship and authoritative membership state when available.
  - Allows save-and-sign-out without losing server-saved progress.
- `lib/router/route_names.dart`, `lib/router/app_routes.dart`, `lib/services/auth_service.dart`
  - New, incomplete, pending, rejected, and resubmission accounts now enter the restricted dashboard.
  - Dashboard, Trips, Earnings, Wallet, Profile, Vehicles, and Notifications remain available while operational ride and money-movement routes stay approval-gated.
  - Suspended accounts and mandatory password changes remain separately gated.

### Profile save, reminders, and online eligibility

- `therainAdmin/firebase/firestore.rules`
  - Allows an authenticated driver to read only `driver_verifications/{theirUid}` even when it does not yet exist, so the seed transaction can create it.
  - Other drivers remain denied and driver update/self-approval permissions were not broadened.
- `therainAdmin/firebase/test/firestore.rules.test.js`
  - Reproduces the complete read-then-create transaction and proves cross-driver reads still fail.
- `lib/features/dashboard/screens/driver_dashboard_screen.dart`
  - Adds a persistent setup/review card linked to the application checklist.
  - Disables Go Online whenever approval or another eligibility gate is missing.
  - Subscribes to incoming rides only for an approved, active, eligible driver who is online.
- `lib/features/notifications/screens/notifications_screen.dart`
  - Adds a non-dismissible profile-completion/review notification that remains until approval.
- `lib/data/models/driver_profile.dart`
  - Centralizes the approved ride-operation and online request-listener policy for consistent enforcement and testing.

### Vehicle, payout, review, and pending experience

- `lib/features/verification/screens/driver_profile_setup_screen.dart`
  - Removed duplicate visible identity inputs for normal email signup.
  - Displays the signed-in account as a compact identity summary with an explicit Edit action.
  - Keeps vehicle and payout data editable and preserves missing-account-field recovery for Google-created accounts.
- `lib/features/verification/screens/verification_review_submit_screen.dart`
  - Replaced 16 flat rows with four grouped sections.
  - Makes account, vehicle/payment, work relationship, and documents independently reviewable.
- `lib/features/verification/screens/verification_pending_screen.dart`
  - Shows affiliation and Fleet relationship.
  - Shows National ID, driver's licence, and live selfie states tied to the driver.
  - Makes clear that Fleet membership and TheRain KYC approval are separate.
  - Resubmission returns to the application home instead of restarting a blind screen chain.

### Fleet relationship

- `lib/data/models/driver_profile.dart`
  - Added `effectiveFleetId`, preferring canonical `currentFleetId` with legacy `fleetId` fallback.
- `lib/services/driver_profile_service.dart`
  - Fleet info loading now uses `effectiveFleetId`.
- `lib/features/verification/screens/fleet_join_screen.dart`
  - A Fleet driver cannot continue until an invitation exists or a server-validated join request has been sent.
- `lib/services/auth_service.dart`
  - Final submission retries canonical `regionId`, `affiliationType`, `serviceTypes`, and `vehicleCategory` through node-api before uploading/submitting KYC.

### Rider call and message

- `lib/features/rides/widgets/ride_common.dart`
  - Call and Message are hidden by default.
  - Assigned-trip screens opt in with `showContact: true`.
  - Call opens the device dialer; Message opens the device SMS app.
  - Failures now show a specific, non-crashing message.
- `lib/features/rides/screens/new_ride_request_screen.dart`
  - Candidate request UI receives no actionable rider phone.
- `lib/features/rides/screens/go_to_pickup_screen.dart`
- `lib/features/rides/screens/pickup_confirmed_screen.dart`
- `lib/features/rides/screens/trip_in_progress_screen.dart`
  - Assigned-trip screens show both contact actions from one reusable control.
- `lib/data/repositories/ride_repository.dart`
  - The accepted ride now stores the assigned rider name and phone so contact still works after app restart.

## 4. Relationship Contract Used

| Entity | Relationship | Authority |
| --- | --- | --- |
| `users/{uid}` | Firebase identity and role | Firebase Auth plus trusted backend/admin role writes |
| `drivers/{uid}` | Driver application, taxonomy, current Fleet/vehicle cache, online eligibility | Driver safe fields plus node-api/admin protected fields |
| `driver_verifications/{uid}` | National ID, licence, selfie, aggregate KYC review | Driver uploads; TheRain admin reviews |
| `payout_accounts/{uid-default}` | Driver receiving account | Driver owns safe account details; payout verification remains controlled |
| `fleetMemberships/{membershipId}` | Source of truth for Fleet-driver relationship | node-api only; driver/Fleet can request or respond but cannot self-activate |
| `vehicles/{vehicleId}` / current vehicle fields | Vehicle ownership/assignment and approval | Vehicle data plus backend/admin approval |
| `rides/{rideId}` | Assigned ride and post-assignment contact | Backend/validated acceptance lifecycle |

Online eligibility remains gated by application approval, KYC approval, active account, approved vehicle, no active conflicting ride, and wallet/commission eligibility. `canGoOnline` and approval fields remain backend/admin owned.

## 5. Verification Results

- `dart format`: passed.
- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub`: all 33 tests passed.
- Firestore emulator rules suite: all 40 tests passed, including the exact missing-document transaction and cross-driver denial.
- New widget coverage proves contact actions are absent before assignment and present after assignment.
- New model assertions cover canonical and legacy Fleet ID resolution.
- New model assertions prove pending drivers cannot receive rides and approved drivers listen only while online.
- `flutter build apk --release --no-pub`: completed successfully.
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- APK size: 120,903,461 bytes (115.3 MB).
- APK SHA-256: `8D7A13498D07950F990C40A873BFE1B2F736B676FD636D183D74C95552D4B265`
- APK identity: `com.therain.driver`, version `1.0.0` (`versionCode 1`), label `TheRain Driver`.
- Android: min SDK 24, target SDK 36.
- APK Signature Scheme v2 verification: passed.
- ADB release install with `-r`: passed on device `123344551J006374`; existing app data was preserved.
- Device startup: passed. The release app remained alive with `MainActivity` visible and no TheRain fatal exception.
- Device Firestore proof: the app created the previously missing verification document, loaded the pending/not-started profile, and routed to `/dashboard` without the former save error.
- Device UI proof: profile setup reminder visible, Go Online visibly disabled, and persistent setup notification visible in Notifications.
- No OTP, payment, ride request, or repeated account creation was triggered.

## 6. Remaining Blockers

### P0: ride acceptance still spans two incompatible backend paths

The Driver app accepts `ride_requests` with a direct Firestore transaction, while node-api uses canonical `rides` plus `candidateDriverIds`. The current Firestore rules for `ride_requests` authorize `resource.data.driverId`, but the active driver query and dispatcher use `assignedDriverId`. The direct transaction also creates `rides/{rideId}` and updates protected driver status fields that the current rules do not narrowly authorize.

Files:

- Driver: `lib/data/repositories/ride_repository.dart`
- Rules: `therainAdmin/firebase/firestore.rules`
- Canonical backend: `therainAdmin/node-api/services/ride.service.js`
- Rider bridge: `therian/backend/src/services/firestore-bridge.ts`

Required fix: move offer accept/decline into one node-api transaction and make both mobile apps use that contract. Do not broaden Firestore rules to arbitrary driver writes.

### P0: backend contact privacy is not yet enforced

The UI hides contact before assignment, but both the Rider Firestore bridge and node-api currently write `riderPhone` into candidate-visible request/ride records before a driver wins assignment. A modified client could still inspect that field.

Required fix: store contact in a private ride-contact record or return it from an assigned-driver-only endpoint after acceptance. Candidate payloads must omit the phone. This requires backend and rule changes, not another UI condition.

### P1: no canonical in-app chat service exists

The implemented Message action opens SMS. There is no audited `ride_messages` collection, message endpoint, participant rule, moderation/retention policy, or notification contract. Calling it in-app chat would be an overclaim.

Required fix: define a participant-only chat contract, then add FCM-backed conversation UI. Keep SMS as fallback.

### P1: deeper physical lifecycle validation remains

Release install, cold start, profile repair, restricted dashboard routing, reminder visibility, and the disabled online state are confirmed. Fresh email signup, KYC image capture/upload, Fleet joining, admin approval transition, real ride offer, assigned rider call, and assigned rider SMS were not exercised in this pass because that would require controlled test identities and live lifecycle data.

### P2: release packaging

The universal APK is 115.3 MB and still reports version `1.0.0` / code `1`. Before external distribution, bump versioning and prefer an Android App Bundle or split-per-ABI APKs.

## 7. Deployment Status

- Driver app source: committed locally in `6666f56`.
- Release APK: built.
- APK installed: yes, release installed with existing app data preserved.
- Firebase rules: tested and deployed only to `therain-production` on 2026-08-03; no indexes or Storage rules deployed.
- node-api: inspected only, not deployed.
- Functions: not changed or deployed.
- Production data: the authenticated app idempotently created its own missing `driver_verifications/{uid}` seed document during device validation; no production data was deleted.
- OTP/payment activity: none.

## 8. Commands Run

- `rg`, `Get-Content`, `git status`, `git diff --check`
- `dart format ...`
- `flutter analyze --no-pub`
- `flutter test --no-pub`
- `flutter build apk --release --no-pub`
- `npm run test:rules`
- `firebase deploy --only firestore:rules --project therain-production --config firebase.json`
- `adb devices`, `adb install -r`, `adb logcat`, `adb shell dumpsys activity`, `adb shell uiautomator dump`, `adb shell screencap`
- `aapt dump badging ...`
- `apksigner verify --verbose ...`
- `Get-FileHash -Algorithm SHA256 ...`

## 9. Next Exact Steps

1. Consolidate ride offer, accept, and decline into node-api and add integration tests for one-driver-wins, approved-driver-only acceptance, and Fleet wallet eligibility.
2. Remove rider phone from all candidate-visible records; expose contact only after assignment.
3. Use controlled driver/admin test identities to validate fresh signup, KYC capture/upload, Fleet request, approval transition, assigned-ride call, and assigned-ride SMS end to end.
4. Decide whether SMS is sufficient for launch. If not, approve a `ride_messages` backend/rules/FCM contract before building in-app chat UI.
5. Bump Android versioning and produce the Play Store AAB after deeper lifecycle validation passes.
