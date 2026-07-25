# TheRain Driver App

Flutter application for drivers on the TheRain platform (Bamenda, Cameroon).

## Backend

Most protected operations (profile sync, applications, fleet membership, vehicle assignment,
online state, and — since Phase 6B — every post-acceptance ride transition: en route, arrived,
start, cancel, complete) call node-api. Ride-offer delivery and initial acceptance/decline
(`watchIncomingRequest`/`acceptRideRequest`/`declineRideRequest`) still use direct Firestore
reads/transactions, not node-api — see `therainAdmin/docs/platform/phase-6b/DECISION_LOG.md`
D-025 for why that specific gap remains. node-api base URL:

```
Production:  https://node-api-production-3f5f.up.railway.app
Local dev:   http://10.0.2.2:8080  (Android emulator → host machine port 8080)
```

Firebase project: `therain-production`

## Setup

1. **Install Flutter** (SDK ^3.11.0)

2. **Copy the environment file:**
   ```sh
   cp .env.example .env
   ```
   Edit `.env` to fill in `API_BASE_URL` and `GOOGLE_MAPS_API_KEY`. `.env` is **not** bundled as a Flutter asset (removed from `pubspec.yaml` after a past incident where a release APK shipped with backend secrets embedded — see `AGENTS.md`); it's read at runtime via `flutter_dotenv` and must only ever contain client-safe keys (see the table below).

3. **Install dependencies:**
   ```sh
   flutter pub get
   ```

4. **Run locally (Android emulator):**
   ```sh
   flutter run
   ```

5. **Build for release (Android):**
   ```sh
   flutter build apk --release
   ```

## Environment Variables (`.env`)

| Key | Description |
|-----|-------------|
| `FIREBASE_API_KEY` | Firebase Web API key |
| `FIREBASE_PROJECT_ID` | `therain-production` |
| `FIREBASE_STORAGE_BUCKET` | `therain-production.firebasestorage.app` |
| `FIREBASE_MESSAGING_SENDER_ID` | `8765794703` |
| `FIREBASE_APP_ID` | Android app ID |
| `GOOGLE_MAPS_API_KEY` | Android Maps SDK key |
| `API_BASE_URL` | node-api base URL |
| `ENABLE_PREVIEW_MODE` | Enable dev-only preview fixtures (`false`) |
| `ENABLE_MOCK_FALLBACK` | Fall back to mock data on API error (`false`) |
| `ENABLE_GOOGLE_SIGN_IN` | Enable Google Sign-In option (`true`) |

## Firebase Configuration

Firebase is wired to `therain-production` in:
- `lib/firebase_options.dart` — programmatic options for Android, iOS, web
- `android/app/google-services.json` — Android native integration

**Do not** run `flutterfire configure` against a different project.

## Authentication Flow

1. Driver signs in via Firebase Phone Auth or Google Sign-In
2. KYC documents are uploaded to Firebase Storage and recorded in Firestore `driver_verifications`
3. Approval is granted by a verificationAdmin through the admin dashboard (never self-approved)
4. After approval, driver can accept and complete rides

## Key Collections (Firestore)

| Collection | Purpose |
|---|---|
| `drivers` | Driver profiles |
| `driver_verifications` | KYC documents and approval status |
| `driver_documents` | Individual uploaded documents |
| `driver_live_locations` | Real-time driver GPS positions |
| `ride_requests` | Incoming ride requests |
| `rides` | Active and completed rides |
| `driver_notifications` | Push notification history |
| `driver_support_tickets` | In-app support |
| `driver_wallets` | Driver earnings wallet |
| `driver_transactions` | Wallet transaction history |

## Project Structure

```
lib/
  app/          ← Root app widget
  config/       ← env_config.dart (reads .env), firebase_config.dart
  core/         ← Shared utilities, constants, extensions
  data/         ← Models, repositories, API data sources
  features/     ← Feature modules (auth, rides, earnings, etc.)
  firebase/     ← Firebase service wrappers
  router/       ← App routing
  services/     ← Service layer
  theme/        ← App theme
```
