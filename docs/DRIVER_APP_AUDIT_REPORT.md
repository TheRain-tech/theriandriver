# TheRain Driver App - Audit Report & Implementation Plan

This document contains a comprehensive inspection, backend protection audit, and structural analysis of the **TheRain Driver** application. It serves as the baseline reference before proceeding with functional enhancements or integrations.

---

## 1. Project Structure Inspected
The project follows a feature-first clean architecture pattern under the `lib/` directory:

```
lib/
├── app/
│   └── therain_driver_app.dart              # MaterialApp, route guards, and theme configuration
├── config/
│   ├── env_config.dart                       # Environment variables configuration (.env file loader)
│   └── firebase_config.dart                  # Firebase initialization logic and mock fallback configuration
├── core/
│   ├── constants/                            # Common constants
│   ├── utils/                                # Helper utilities
│   └── widgets/                              # Reusable common UI widgets
├── data/
│   ├── mock/                                 # Static mock datasets for preview and offline development
│   ├── models/                               # Data models & serialized entities (e.g. DriverProfile, RideRequest)
│   └── repositories/                         # Data layer abstractions (e.g. RideRepository, DriverRepository)
├── features/                                 # Feature-specific presentation layers (screens, widgets, controllers)
│   ├── auth/                                 # Onboarding, Login, Signup, Startup screens
│   ├── dashboard/                            # Core driver dashboard and map interface
│   ├── earnings/                             # Earning metrics and daily/weekly summaries
│   ├── fuel/                                 # Fuel tracking interface (mock-only)
│   ├── notifications/                        # Push alert center
│   ├── profile/                              # Driver profile configuration
│   ├── promotions/                           # Active incentive/promo displays (mock-only)
│   ├── rides/                                # Active ride states: pickup, transition, trip screens
│   ├── shared/                               # Shared UI features
│   ├── subscription/                         # Driver premium subscription status (mock-only)
│   ├── support/                              # SOS triggers, help center, ticket history
│   ├── vehicle/                              # Vehicle information and documents lists (mock-only)
│   ├── verification/                         # Registration stepper: ID upload, license, selfie capture
│   └── wallet/                               # Driver cash-out and transaction screens
├── firebase/
│   ├── firestore_collections.dart            # Standard Firestore collection & ride status constants
│   └── firestore_paths.dart                  # Relative Firestore document path resolvers
├── router/
│   ├── app_routes.dart                       # Route generator, security verification, and status guards
│   └── route_names.dart                      # Decoupled navigation path constants
├── theme/
│   ├── app_colors.dart                       # Brand colors definitions
│   ├── app_text_styles.dart                  # Typography configuration
│   └── app_theme.dart                        # Core ThemeData (light style)
├── firebase_options.dart                     # Production Firebase app credentials
└── main.dart                                 # App bootstrap entry point (initializes dotenv & Firebase)
```

---

## 2. Dependencies and Configuration Found
An analysis of `pubspec.yaml` reveals the following:

### Dependencies Already Installed
*   **Firebase Suite**: `firebase_core: ^4.9.0`, `firebase_auth: ^6.5.1`, `cloud_firestore: ^6.4.1`, `firebase_storage: ^13.4.1`, `firebase_messaging: ^16.2.2`, `cloud_functions: ^6.3.1`.
*   **Location & Maps**: `google_maps_flutter: ^2.17.0`, `geolocator: ^14.0.2`, `permission_handler: ^12.0.3`, `flutter_polyline_points: ^3.1.0`.
*   **Utilities & System**: `flutter_dotenv: ^6.0.0`, `uuid: ^4.5.3`, `intl: ^0.20.2`, `connectivity_plus: ^7.0.0`, `url_launcher: ^6.3.2`, `http: ^1.6.0`.
*   **Hardware Interface**: `camera: ^0.12.0+1`, `image_picker: ^1.2.1`.

### Dependencies Missing
*   **State Management**: There is no state management package (e.g. `provider`, `flutter_bloc`, `riverpod`, or `get`) installed in the dependencies. The application currently relies on native `ValueNotifier` structures (e.g. `DriverProfileService.instance.profile`).

### Dependencies Unused or Risky
*   No direct version conflicts were observed. The dependencies list is well-scoped and modern.

### Asset Registration
*   Assets are registered globally as:
    *   `.env`
    *   `assets/`
    *   `assets/screens/`
*   Actual assets inside the `assets/` and `assets/screens/` directories contain high-resolution PNG/JPG mock design assets.

---

## 3. Firebase Setup Found
*   **Initialization Status**: Configured via `FirebaseConfig.initialize()` inside `lib/main.dart` loading `DefaultFirebaseOptions.currentPlatform` (generated for project ID `therain-production`).
*   **Fallback Mode**: Supports a debug-mode mock fallback using local models when Firebase is offline if `ENABLE_MOCK_FALLBACK` is `true` in the `.env` file.
*   **Auth Status**: Configured with `FirebaseAuth` in `AuthRepository`.
*   **Firestore Status**: Persistence is explicitly enabled (`persistenceEnabled: true`) in `FirebaseConfig`.
*   **Storage Status**: File and raw bytes uploads are handled via `FirebaseStorageService` referencing `FirebaseStorage.instance`.
*   **Messaging Status**: Managed by `NotificationService` (requests permissions, retrieves, and maps FCM tokens to the `drivers` collection).
*   **Configuration Files**:
    *   `android/app/google-services.json` is configured for package `com.therain.driver` (also includes `com.therain.rider`).
    *   `ios/Runner/GoogleService-Info.plist` is configured for bundle `com.therain.driver`.
*   **Security & Secrets**: Firebase keys are stored within public client configuration files (`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`). This matches Firebase design standards (API keys represent client IDs, not project secrets).

---

## 4. Authentication Flow Found
1.  **Driver Registration**: Handles full-name, phone number, email, and password registration in `AuthService.signUp`. Seeds both the shared user entry in `users` and a profile record in `drivers` via a Firestore batch write inside `DriverRepository.seedDriverProfile`.
2.  **Driver Login**: Executes standard email/password authentication using `AuthService.signIn`.
3.  **Startup Routing**: Handled securely via `AuthService.landingRouteForCurrentUser`.
    *   Fetches the active driver profile using `DriverRepository.getProfile`.
    *   If no profile exists, routes to `RouteNames.profileSetup`.
    *   Checks account status (if suspended or blocked, routes to `RouteNames.suspended`).
    *   Maps verification status:
        *   `approved`: Restores active ride redirection (`goToPickup`, `pickupConfirmed`, or `tripInProgress` depending on current ride status) or default `dashboard`.
        *   `pending`: Routes to `RouteNames.pending` screen.
        *   Otherwise (rejected, notStarted, inProgress): Routes to `RouteNames.profileSetup`.
4.  **Logout Flow**: Clears FCM subscriptions, sets the driver profile `onlineStatus` to `offline` via `DriverRepository.setOffline`, terminates Geolocator tracking via `LocationService.instance.stopDriverTracking`, clears listeners, and signs out of FirebaseAuth.

---

## 5. Driver Registration and Verification Flow Found
*   **Verification Steps**: The verification flow is a multi-step form managed via `RegistrationDraftService.instance.draft` (storing state locally before final submission).
    *   **Step 1: Driver Profile Setup** (`lib/features/verification/screens/driver_profile_setup_screen.dart`): Saves contact details and vehicle selection (`classic` is default) via `DriverRepository.saveProfileSetup`.
    *   **Step 2: National ID Document** (`lib/features/verification/screens/national_id_verification_screen.dart`): Collects National ID number and gallery upload.
    *   **Step 3: Driver License** (`lib/features/verification/screens/driver_licence_verification_screen.dart`): Collects License number, expiry date, and photo.
    *   **Step 4: Identity Selfie** (`lib/features/verification/screens/live_selfie_verification_screen.dart`): Launches device camera to capture a portrait photo.
    *   **Step 5: Review & Submit** (`lib/features/verification/screens/verification_review_submit_screen.dart`): Calls `DriverVerificationRepository.submit`.
*   **Document Upload Paths**:
    *   National ID: uploads to `driver_verifications/$uid/national_id.jpg` (or local file path if offline).
    *   License: uploads to `driver_verifications/$uid/licence.jpg`.
    *   Selfie: uploads to `driver_verifications/$uid/selfie.jpg`.
*   **Firestore Records**: Creates a single verification metadata record in the `driver_verifications` collection keyed by the driver's `uid`, and updates the corresponding driver's document in the `drivers` collection setting `verificationStatus` to `'pending'` and `canReceiveRides` to `false`.

---

## 6. Map and Location Logic Found
*   **Device Permission Handling**: Checked dynamically in `LocationService.ensurePermission()`. Throws a detailed `LocationAccessException` if location permissions are denied, denied forever, or if the device GPS is disabled.
*   **Current Location**: Retrieves high-accuracy GPS coordinates (`Geolocator.getCurrentPosition`).
*   **Live Updates**: When going online, starts a location stream via `Geolocator.getPositionStream` (using a 10-meter change filter) and sends updates to `LocationRepository.updateDriverLocation` (which writes to the `driver_live_locations` collection).
*   **Online/Offline Status Gating**: The stream runs only while the driver is online. Setting status to offline terminates the Geolocator subscription.
*   **Active Ride Redirection**: During active trips, the system tracks the customer's coordinates via `LocationRepository.watchRiderLocation` reading the `rider_live_locations` collection.

---

## 7. Ride Request and Trip Lifecycle Logic Found
*   **Listening to Requests**: `RideRepository.watchIncomingRequest(uid)` listens to the `ride_requests` collection where `assignedDriverId == uid` and `status == 'searching'`.
*   **Request Expiration**: Filters expired requests using `RideRequest.isExpired` based on the request's `expiresAt` timestamp.
*   **Ride Lifecycle Transitions**:
    *   **Accept Request**: Updates `ride_requests` status to `accepted`, creates a new document in `rides` collection, and modifies the driver's status to `busy` and `currentRideId` to the ride ID via a multi-document **Firestore Transaction**.
    *   **Arrive at Pickup**: Transitions ride status from `accepted` -> `driver_arriving` -> `arrived` via `RideRepository.transitionRide`.
    *   **Start Trip**: Transitions status to `ongoing` and sets the timestamp `startedAt` via transaction.
    *   **Complete Ride**: Calls cloud function `completeRideAndSettleEarnings`. If offline or in development mode, uses `_completeRideDevelopmentFallback` which updates `rides` to `completed`, increments driver statistics (trips, earnings, wallet balance), and posts a transaction log.
    *   **Cancel Ride**: Sets status to `cancelled`, updates driver back to `online` / `status = 'online'`, and clears `currentRideId`.

### Alignment of Ride Statuses
Official TheRain statuses vs existing local references:

| Official Status | Local Constant (`RideStatuses`) | Alignment Status |
| :--- | :--- | :--- |
| `draft` | *Not explicitly used in Driver* | Implemented on Rider side |
| `fare_estimated` | *Not explicitly used in Driver* | Implemented on Rider side |
| `searching_driver` | `searching` | **Aligned** |
| `requested_specific_driver`| *Not explicitly used* | Will map to `searching` |
| `driver_assigned` | `accepted` | **Aligned** |
| `driver_rejected` | *Handled via nulling ID* | **Aligned** |
| `request_timeout` | `expired` | **Aligned** |
| `driver_arriving` | `driver_arriving` | **Aligned** |
| `driver_arrived` | `arrived` | **Aligned** |
| `in_progress` | `ongoing` | **Aligned** (local mapped to `ongoing`) |
| `completed` | `completed` | **Aligned** |
| `cancelled_by_rider` | `cancelled` | **Aligned** (uses combined status) |
| `cancelled_by_driver` | `cancelled` | **Aligned** (uses combined status) |
| `no_driver_found` | *Not used in Driver* | Implemented on Rider side |
| `payment_pending` | *Mapped in paymentStatus* | **Aligned** (via PaymentStatuses) |
| `paid` | *Mapped in paymentStatus* | **Aligned** (via PaymentStatuses) |
| `payment_failed` | *Mapped in paymentStatus* | **Aligned** (via PaymentStatuses) |

---

## 8. Wallet, Earnings, and Payment Logic Found
*   **Wallet Setup**: Managed by `DriverWalletRepository`. Listens to the `driver_wallets` document for the authenticated driver.
*   **Transaction Logs**: Listens to the `driver_transactions` collection for the authenticated driver.
*   **Cash-Out Requests**: Calls the Cloud Function `createWithdrawalRequest`. Includes a developmental client fallback that writes a pending withdrawal transaction document to Firestore (wallet balance is strictly server-managed and cannot be adjusted directly from the client).
*   **Earnings Calculation**: Computed dynamically by querying completed transactions from the current week inside `DriverEarningRepository`.

---

## 9. Documents, Support, SOS, and Notification Logic Found
*   **Support Tickets**: Logged under `driver_support_tickets` in Firestore. Support attachments (screenshots) upload to storage path `driver_support_tickets/$uid/$ticketId/screenshot.jpg`.
*   **SOS Alerts**: Logged under `sos_alerts` in Firestore. Captures driver ID, name, phone number, and current GPS coordinates.
*   **Push Notifications**: Listens to FCM events foreground and background. Maps notifications using the `notifications` collection in Firestore.

---

## 10. Firestore Collections Currently Used
The application uses the following Firestore collections:

| Collection Name | Reference Constant (`FirestoreCollections`) | Purpose & Write Locations | Critical Safety |
| :--- | :--- | :--- | :--- |
| `users` | `users` | Shared customer/driver registry. Written in `DriverRepository.seedDriverProfile` and `saveProfileSetup`. | **High** - Shared with Rider App |
| `drivers` | `drivers` | Profile information, online statuses, current rides. | **High** - Core entity |
| `driver_verifications` | `driverVerifications` | Registration steps, photos, numbers, review flags. Written in `DriverVerificationRepository.submit`. | **High** - Integrity check |
| `driver_live_locations` | `driverLiveLocations` | Live driver GPS updates. Written in `LocationRepository.updateDriverLocation`. | Medium - Ephemeral |
| `rider_live_locations` | `riderLiveLocations` | Rider position lookup (read-only for driver). | Medium - Ephemeral |
| `ride_requests` | `rideRequests` | Offers assigned to drivers. Updated in `RideRepository` (accept, decline, transitions). | **High** - Core lifecycle |
| `rides` | `rides` | Active trips history. Written in `RideRepository` (accept, transitions, completes). | **High** - Core lifecycle |
| `driver_wallets` | `driverWallets` | Balance and cashout configurations. Updated in `RideRepository` (fallback complete). | **High** - FinTech security |
| `driver_transactions` | `driverTransactions` | Account credit/debit records. Written in `DriverWalletRepository` and `RideRepository`. | **High** - FinTech security |
| `notifications` | `notifications` | System messages. Updated in `DriverNotificationRepository`. | Low - Display data |
| `driver_support_tickets` | `driverSupportTickets` | Customer care logs. Written in `DriverSupportRepository.createTicket`. | Low - Support records |
| `driver_activity_logs` | `driverActivityLogs` | Tracking declined requests. Written in `RideRepository.declineRideRequest`. | Medium - Auditing |
| `sos_alerts` | `sosAlerts` | Panic buttons events. Written in `SosRepository.sendSosAlert` / `DriverSupportRepository.createSosAlert`. | **High** - Life safety |

---

## 11. Storage Paths Currently Used
The application writes to the following path structures in Firebase Storage:
*   `driver_verifications/$uid/national_id.jpg` - Image of National ID card.
*   `driver_verifications/$uid/licence.jpg` - Image of Driver's License.
*   `driver_verifications/$uid/selfie.jpg` - Live verification selfie portrait.
*   `driver_support_tickets/$uid/$ticketId/screenshot.jpg` - Screenshot attachment for support tickets.

---

## 12. Current Route/Navigation Structure
The routing is managed by `AppRoutes.onGenerateRoute` using path strings from `RouteNames`:
*   `RouteNames.startup` (`/startup`) -> `StartupScreen()`: Bootstrap check.
*   `RouteNames.onboarding` (`/`) -> `OnboardingScreen()`: Welcoming screen.
*   `RouteNames.login` (`/login`) -> `LoginScreen()`: Credentials entry.
*   `RouteNames.signup` (`/signup`) -> `SignupScreen()`: Account creation.
*   `RouteNames.profileSetup` (`/verification/profile`) -> `DriverProfileSetupScreen()`: Stepper step 1.
*   `RouteNames.nationalId` (`/verification/national-id`) -> `NationalIdVerificationScreen()`: Stepper step 2.
*   `RouteNames.licence` (`/verification/licence`) -> `DriverLicenceVerificationScreen()`: Stepper step 3.
*   `RouteNames.selfie` (`/verification/selfie`) -> `LiveSelfieVerificationScreen()`: Stepper step 4.
*   `RouteNames.review` (`/verification/review`) -> `VerificationReviewSubmitScreen()`: Stepper review and submit.
*   `RouteNames.pending` (`/verification/pending`) -> `VerificationPendingScreen()`: Awaiting review screen.
*   `RouteNames.approved` (`/verification/approved`) -> `VerificationApprovedScreen()`: Verification success landing.
*   `RouteNames.dashboard` (`/dashboard`) -> `DriverDashboardScreen()`: Main map dashboard.
*   `RouteNames.rideRequest` (`/rides/request`) -> `NewRideRequestScreen()`: Pop-up overlay.
*   `RouteNames.goToPickup` (`/rides/pickup`) -> `GoToPickupScreen()`: Map showing pickup navigation.
*   `RouteNames.pickupConfirmed` (`/rides/pickup-confirmed`) -> `PickupConfirmedScreen()`: Driver arrived.
*   `RouteNames.tripInProgress` (`/rides/in-progress`) -> `TripInProgressScreen()`: On the road.
*   `RouteNames.tripCompleted` (`/rides/completed`) -> `TripCompletedScreen()`: Trip complete summary.
*   `RouteNames.suspended` (`/suspended`) -> `AccountSuspendedScreen()`: Suspension warning screen.

---

## 13. UI/Brand Alignment Observations
The application styles are aligned with TheRain's branding palette inside `lib/theme/app_colors.dart`:
*   **Primary Navy** is mapped as `AppColors.navy` (`#071936`).
*   **Primary Blue** is mapped as `AppColors.primary` (`#1262F6`) and `AppColors.primaryDark` (`#0649CC`).
*   **Success Green** is mapped as `AppColors.success` (`#12B84B`).
*   **Warning Yellow** is mapped as `AppColors.warning` (`#F59E0B`).
*   **Danger Red** is mapped as `AppColors.danger` (`#EF202B`).
*   **Backgrounds & Borders** use light gradients and soft styles (`AppColors.background` `#F8FAFD` and `AppColors.border` `#DCE4EF`).

---

## 14. Security Checks Already Implemented
1.  **Route Gating**: `AppRoutes._guard` forces all protected screens to redirect to `suspended` if the account status is blocked/suspended, or to `verification` screens if the driver is not yet approved.
2.  **Online Status Gating**: `DriverRepository.setOnline` queries the driver document first via transaction, ensuring that `verificationStatus == 'approved'` and `canReceiveRides == true` before allowing a driver to transition online.
3.  **GPS & Location Service Gating**: `LocationService.ensurePermission` validates both location permission rules and ensures device GPS hardware is active before allowing the driver to go online.
4.  **Server-Side Wallet Operations**: Client balance modifications are not allowed. Withdrawal requests (`DriverWalletRepository.requestWithdrawal`) and ride completions (`RideRepository.completeRide`) utilize Firebase Cloud Functions for transaction security.
5.  **Sensitive Keys Management**: Android Maps API keys are injected at build time via gradle placeholders, and iOS Maps API keys are fetched dynamically fromBundle plist parameters, avoiding hardcoded source files.

---

## 15. Missing or Weak Security Checks
*   **Draft Verification Access**: Currently, step routing within the registration steps is not strictly ordered; drivers can navigate directly to `RouteNames.review` if they know the route, though the repository validates completeness before committing to Firestore.
*   **Local UI Bypassing**: When preview/mock mode is active (`EnvConfig.previewMode = true`), security checks are bypassed entirely. While acceptable for testing, ensure this option is compile-time locked in production builds.

---

## 16. Existing Backend Logic That Must Be Protected
*   **`RideRepository.acceptRideRequest`**: Implemented using a critical Firestore transaction that checks if request status is still `searching` and `assignedDriverId` is `uid` before committing, preventing double-assignment races.
*   **`DriverRepository.setOnline`**: The transaction validation of approval status must not be modified or bypassed.
*   **`DriverWalletRepository` & `RideRepository` Cloud Function Calls**: Client calls to `createWithdrawalRequest` and `completeRideAndSettleEarnings` must be preserved as the primary channels for finance and trip completion.

---

## 17. Duplicates or Risky Code Found
*   **SOS Alert Redundancy**: Both `SosRepository.sendSosAlert` and `DriverSupportRepository.createSosAlert` contain identical implementation logic writing to the `sos_alerts` collection.
*   **Profile Repositories Redundancy**: `DriverProfileRepository` is a simple mock repository that is unused in production services. The real Firebase operations are handled by `DriverRepository`.
*   **Development Fallback**: In `RideRepository._completeRideDevelopmentFallback`, client-side updates directly write balance increments to `driver_wallets` and `drivers` collections. While useful for local staging, this must never be triggered in production.

---

## 18. Flutter Analyze / Test Results
*   **`flutter pub get`**: Completed successfully with all package constraints resolved.
*   **`flutter analyze`**: Ran cleanly and completed with `No issues found!`.
*   **`flutter test`**: Completed with `All tests passed!`.

---

## 19. Recommended Implementation Order for Next Prompts
1.  **Prompt 2: Registration, Document Uploads, and Verification Stepper**:
    *   Implement image picking & live camera selfie integration.
    *   Hook up `FirebaseStorageService` uploads for license, national ID, and selfie.
    *   Connect `DriverVerificationRepository.submit` to write data to Firestore.
    *   Verify the status listening logic redirection to the pending screen.
2.  **Prompt 3: Location tracking & Online Toggle Integration**:
    *   Hook up location permission request alerts.
    *   Implement background/foreground GPS location upload to `driver_live_locations`.
    *   Connect the Dashboard online/offline toggle with transaction status verification.
3.  **Prompt 4: Ride Request Acceptance & active lifecycle**:
    *   Integrate the incoming ride request streams.
    *   Implement acceptance transaction and vehicle validation.
    *   Build active trip transitions (pickup, ongoing, arrival).
4.  **Prompt 5: Earnings, Wallet & Cash-out**:
    *   Integrate real transaction history streams.
    *   Wire up the withdrawal request API and limit checks.

---

## 20. Clear "Do Not Touch" List
*   **Do not modify** `firebase_options.dart`, `google-services.json`, or `GoogleService-Info.plist` (production Firebase connection).
*   **Do not remove** the route status gates in `AppRoutes.onGenerateRoute` / `_guard`.
*   **Do not modify** transaction logic in `RideRepository.acceptRideRequest` or `DriverRepository.setOnline`.
*   **Do not change** Firestore collection names specified in `FirestoreCollections`.
*   **Do not bypass** Google Maps API keys configuration in Gradle or plist parameters.

---

## 21. Final Inspection Summary
*   **Is the app safe to continue building on?**: **Yes**. The existing project base is clean, follows proper separation of concerns, has an error-free analysis status, and utilizes secure Firebase transaction patterns.
*   **Which backend services already exist?**: Real Firestore, Storage, Auth, and Messaging connectors exist within repository services, but are guarded by preview/mock condition switches.
*   **Which files are sensitive and must be protected?**:
    *   `lib/firebase_options.dart` (Production configurations)
    *   `lib/data/repositories/ride_repository.dart` (Transaction security)
    *   `lib/data/repositories/driver_repository.dart` (Online permission status rules)
    *   `lib/router/app_routes.dart` (Guards for suspended & unverified accounts)
*   **Which exact part should be handled in Prompt 2?**: Registration, document upload stepper, selfie capture integration, and verification submit transitions.
*   **Which exact parts should wait for later prompts?**: Location tracking streams (Prompt 3), Ride lifecycle transitions (Prompt 4), and Wallet/Earnings financial features (Prompt 5).
