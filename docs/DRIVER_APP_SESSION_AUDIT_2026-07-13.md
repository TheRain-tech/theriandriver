# TheRain Driver App - Session Audit (2026-07-13)

This report covers the driver lifecycle review, the bugs found while investigating
real-device failure reports, and every code/config change made in this session.
It supersedes nothing in `docs/DRIVER_APP_FINAL_PATCH_REPORT.md` — it documents
what changed *after* that report, once real-device testing surfaced problems the
static analysis and previous audits didn't catch.

---

## 1. Starting Point

Prior sessions (see `docs/DRIVER_APP_FINAL_READINESS_REPORT.md` and
`DRIVER_APP_FINAL_PATCH_REPORT.md`) had already verified: OAuth (Google Sign-In)
and biometric app-lock were implemented, the KYC stepper (ID → licence → selfie →
review → submit → pending → approved) was wired end-to-end, and `flutter analyze`
was clean. This session started from a real-device test report of concrete
failures in that flow.

---

## 2. Bugs Found & Fixed

### Bug 1: Ride acceptance silently failing (Critical) — FIXED, deployed
- **Symptom**: Rider searches for a ride, no driver ever gets assigned, even
  with an online/eligible driver nearby.
- **Root cause**: `RideRepository.acceptRideRequest()` writes a `regionId`
  field when creating the `rides/{rideId}` document (carried forward from the
  ride_request so regional admin dashboards can filter on it), but the
  deployed `firestore.rules` CREATE rule for `rides/{rideId}` didn't include
  `regionId` in its `hasOnly()` allowed-keys list. Every accept was rejected
  with `permission-denied`, so the ride request eventually expired as
  "no driver found."
- **Fix**: Added `'regionId'` to the `rides/{rideId}` create rule's allowed
  keys in `firestore.rules`.
- **Status**: Committed (`4b0972e`) and **deployed to `therain-production`**
  via `firebase deploy --only firestore:rules`.

### Bug 2: Every driver signup fails on final submit (Critical) — FIXED, not yet deployed to app
- **Symptom**: "We started creating a driver and we ended halfway" — the
  account gets created, personal info and documents are entered, but the
  final "Submit" on the review screen fails with "We could not save your
  driver profile. Please try again," and the driver is stuck unable to
  reach `pending`/`approved` at all.
- **Root cause**: `DriverRepository.saveProfileSetup()` is called **twice**
  in the normal signup flow — once when leaving the Profile Setup screen,
  and again inside `AuthService.finalizeDriverOnboarding()` on final submit.
  Both calls write a `payout_accounts/{uid-default}` document with
  `'createdAt': FieldValue.serverTimestamp()`. On the first call this
  *creates* the document (allowed — the create rule permits `createdAt`).
  On the second call it *updates* the same document with a **new**
  timestamp value, but the `payout_accounts` update rule's `hasOnly()` list
  deliberately excludes `createdAt` (to protect it from being overwritten).
  Firestore rejects the whole atomic `WriteBatch` — which also contains the
  `users` and `drivers` writes — with `permission-denied`. This affected
  **100% of driver signups**, not an edge case.
- **Fix**: `saveProfileSetup()` now reads the payout account doc first and
  only includes `createdAt` in the write when the document doesn't already
  exist, matching the idempotent pattern already used in `seedDriverProfile`.
- **File**: `lib/data/repositories/driver_repository.dart`
- **Status**: Fixed in code, `flutter analyze` clean, built into the new APK
  (see §5). No Firestore rules change was needed for this one.

### Bug 3: Google Sign-In throws a client-configuration error — partially fixed, needs a Firebase Console step
- **Symptom**: Tapping "Sign in with Google" throws a
  `GoogleSignInException` with a client-configuration / missing
  server-client-ID error.
- **Root cause**: Two things, both required:
  1. `android/app/google-services.json` has an **empty `oauth_client` list**
     for both `com.therain.driver` and `com.therain.rider` — no SHA-1
     certificate fingerprint has ever been registered for either Android
     app in the Firebase project, so Firebase has never generated an OAuth
     client (Android or Web) for them.
  2. The app code called `GoogleSignIn.instance.initialize()` with no
     `serverClientId`. `google_sign_in: ^7.2.0` uses Android's Credential
     Manager API, which needs a server (Web) OAuth client ID to mint an ID
     token that `GoogleAuthProvider.credential(idToken:)` can exchange with
     Firebase Auth — without it, this exact error is thrown.
- **Fix (code)**: `AuthRepository._ensureGoogleSignInInitialized()` now
  passes `serverClientId: EnvConfig.googleServerClientId` when non-empty.
  Added `GOOGLE_SERVER_CLIENT_ID` to `.env`, `.env.example`, and
  `EnvConfig`.
- **Remaining action (console, not code — see §4)**: Register the app's
  SHA-1 fingerprints in Firebase Console, which causes Firebase to generate
  a Web OAuth client; copy that client ID into `GOOGLE_SERVER_CLIENT_ID` in
  `.env` and rebuild.
- **Files**: `lib/config/env_config.dart`, `lib/data/repositories/auth_repository.dart`,
  `.env`, `.env.example`

---

## 3. Investigated, No Code Bug Found

### Password reset email not arriving
`AuthRepository.sendPasswordResetEmail()` is a direct, correctly-awaited
call to `FirebaseAuth.sendPasswordResetEmail()`; errors are caught and
surfaced via `friendlyError`. No code defect found. Two non-code
explanations to check directly in Firebase Console:
- Firebase Auth has **email enumeration protection** on by default for
  newer projects — `sendPasswordResetEmail` returns success and sends
  nothing if the address has no account, by design (prevents probing which
  emails are registered). Confirm the test email actually has an account
  under Authentication → Users.
- Check the destination inbox's spam folder, and confirm the "Password
  reset" email template is enabled under Authentication → Templates.

### ID front image upload "object not found"
Reviewed `FirebaseStorageService.uploadBytes()`, `storage.rules`, and the
national ID upload screen. `storage.rules` already allows
`national_id_front.jpg` / `national_id_back.jpg` (this was fixed in an
earlier session). The upload path never reads the file back (no
`getDownloadURL()` call), so a Storage `object-not-found` response doesn't
match anything the code currently does. Two candidate explanations, neither
confirmed without a reproduction:
- This may have been a downstream symptom of **Bug 2** above — if a prior
  signup attempt died partway through, retrying could land the picker/draft
  state in an inconsistent spot.
- `image_picker` picking a cloud-only gallery photo (e.g. a Google Photos
  item not fully downloaded to the device) can fail to resolve to a real
  local file on some Android versions. Worth retesting with a camera-taken
  photo stored locally.

**Action for next test pass**: retry both flows now that Bug 2 is fixed,
since that bug could plausibly explain why documents seemed to upload into
a broken account state. If the image error recurs, capture the exact error
text/screenshot — "object not found" doesn't correspond to a call this code
makes today, so pinning it down needs the literal message.

---

## 4. Action Required From You (Firebase Console — cannot be done from code)

To finish fixing Google Sign-In:
1. Get your release keystore's SHA-1 (and SHA-256) fingerprint — run this
   yourself so the keystore password never has to be typed into a chat:
   ```
   keytool -list -v -keystore android\therain-driver-release.keystore -alias therain-driver
   ```
   (enter the store password from `android\key.properties` when prompted).
2. In [Firebase Console](https://console.firebase.google.com/project/therain-production/settings/general) →
   Project Settings → Your apps → `com.therain.driver` → Add fingerprint →
   paste the SHA-1 (and SHA-256).
3. Repeat for your **debug** keystore if you test debug builds — already
   extracted this session:
   - SHA-1: `FB:46:60:19:4B:46:A8:43:85:7E:D8:12:4F:FF:69:2F:7F:D5:7A:1E`
   - SHA256: `F9:5E:BD:B4:33:EC:B5:20:FC:3C:88:16:3D:77:4D:65:E3:AA:8C:CA:50:C3:5D:88:93:49:5F:C7:17:AC:37:DB`
4. Confirm **Google** is enabled as a sign-in provider under Authentication
   → Sign-in method (enabling it is also what causes the Web OAuth client to
   be generated).
5. Re-download `google-services.json` from Project Settings → Your apps →
   `com.therain.driver`, replace `android/app/google-services.json`.
6. Copy the new Web client ID (the `oauth_client` entry with
   `client_type: 3` in the freshly downloaded file) into `GOOGLE_SERVER_CLIENT_ID`
   in `.env`.
7. Rebuild the APK.

---

## 5. Files Changed This Session
- `firestore.rules` — added `regionId` to `rides/{rideId}` create rule (deployed).
- `lib/data/repositories/driver_repository.dart` — fixed `saveProfileSetup()` double-write on `payout_accounts.createdAt`.
- `lib/data/repositories/auth_repository.dart` — pass `serverClientId` to `GoogleSignIn.instance.initialize()`.
- `lib/config/env_config.dart` — added `googleServerClientId` getter.
- `.env`, `.env.example` — added `GOOGLE_SERVER_CLIENT_ID`.

## 6. Commands Run
- `flutter analyze` — No issues found (twice, before and after fixes).
- `firebase deploy --only firestore:rules --project therain-production` — succeeded.
- `flutter build apk --release` — succeeded, see release notes for output path/hash.

## 7. Remaining Before This Is "Flawless"
1. Complete the Firebase Console SHA-1/Web-client-ID steps in §4 — Google
   Sign-In will keep failing until this is done, no amount of app code can
   substitute for it.
2. Re-test driver signup end-to-end on a device with the new APK — Bug 2
   was blocking 100% of signups, so this needs real confirmation, not just
   `flutter analyze`.
3. Re-test password reset against a known-existing account and check spam
   folder / Firebase email template config.
4. Re-test ID document upload; if "object not found" recurs, capture the
   literal error text.
