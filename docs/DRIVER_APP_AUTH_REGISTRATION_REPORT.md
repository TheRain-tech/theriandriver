# TheRain Driver App - Authentication & Driver Registration Audit Report

This report summarizes the verification, repair, and integration work carried out on the Authentication, Startup Routing, and Driver Registration Flow features.

---

## 1. Auth Files Inspected
*   `lib/services/auth_service.dart` - Decoupled auth orchestrator.
*   `lib/data/repositories/auth_repository.dart` - Low-level integration mapping Firebase `User` to custom `AuthUser` models.
*   `lib/features/auth/screens/login_screen.dart` - Form state, validation, and credentials handlers.
*   `lib/features/auth/screens/signup_screen.dart` - Registration handlers and profile initialization seed commands.
*   `lib/features/auth/screens/startup_screen.dart` - Session resolution gates.
*   `lib/router/app_routes.dart` - Routing guards.

---

## 2. Firebase Auth Setup Found
*   Uses standard email/password authentication via `FirebaseAuth.instance.createUserWithEmailAndPassword` and `signInWithEmailAndPassword`.
*   Includes built-in debug fallbacks mapping to hardcoded `mock-driver` users if the Firebase connection is not active and mock fallback is enabled in `.env`.
*   Propagates user updates to `displayName` upon signup.

---

## 3. Startup Routing Implemented or Repaired
*   **Safe Startup**: The launch screen `StartupScreen` executes `AuthService.instance.landingRouteForCurrentUser()`, which:
    *   Authenticates session availability.
    *   Queries active database profiles in the `drivers` collection.
    *   Redirects unverified or newly created drivers to document registration.
    *   Loads active ride contexts for verified drivers, routing them immediately back to active trips (`goToPickup`, `pickupConfirmed`, or `tripInProgress`) if they quit the app during a ride.

---

## 4. Login Functionality Implemented or Repaired
*   Form validation blocks empty or malformed fields on the login screen.
*   The login action runs within a loading spinner state that disables form buttons during submission.
*   Exceptions are captured and mapped via `AuthService.friendlyError` to hide raw Firebase errors (e.g. `wrong-password` maps to a user-friendly notice).
*   Successful authentication redirects to the `StartupScreen` to evaluate route gating instead of bypassing validation directly to the dashboard.

---

## 5. Signup Functionality Implemented or Repaired
*   Creates account credentials within FirebaseAuth.
*   Automatically seeds a new profile document in the `drivers` collection and `users` collection via a Firestore batch write inside `DriverRepository.seedDriverProfile`.
*   Seeds profiles with safe default configuration details:
    *   `role` = `'driver'`
    *   `verificationStatus` = `'notStarted'`
    *   `accountStatus` = `'pending'`
    *   `isOnline` = `false`
    *   `canReceiveRides` = `false`
    *   `currentRideId` = `null`
    *   `rating` = `0`
*   Requires the driver to configure profile details next without granting automatic dashboard access.

---

## 6. Driver Profile Setup Implemented or Repaired
*   Saves contact and vehicle details (vehicleType, plate number, color) directly to Firestore under the `drivers` and `users` collections via `DriverRepository.saveProfileSetup`.
*   Correctly sanitizes inputs (plate number is forced uppercase and trimmed).
*   Transitions `verificationStatus` to `'inProgress'` in the database.

---

## 7. Verification Gating Logic Added/Repaired
*   **Route Guards**: Enhanced the main guard `AppRoutes._guard` to check for active authenticated user sessions. Unauthenticated users attempting to bypass routes are redirected back to the Login screen.
*   **Synchronized State Listener**: Resolved a gap inside `DriverProfileService.bindAuthenticatedDriver` where real-time Firestore profile stream updates did not propagate to `DriverVerificationService`. Syncing the status on watch fires allows immediate navigation updates (e.g., redirecting to the approved welcome screen the moment an administrator approves the driver).

---

## 8. Logout Behavior Added/Repaired
*   Clears user device tokens from the database.
*   Gracefully stops GPS geolocation streams via `LocationService.instance.stopDriverTracking`.
*   Updates `isOnline` and `status` inside the `drivers` collection to offline.
*   Added a **Sign Out** option on the `VerificationPendingScreen` so that unapproved or pending drivers are not trapped on the screen and can sign out to authenticate with other credentials.

---

## 9. Backend Services Preserved
The following core services were preserved and left intact:
*   `LocationService` (Gps permissions and telemetry tracking)
*   `NotificationService` (FCM setups)
*   `RideRepository` (Ride lifecycle transitions and transactions)
*   `DriverWalletRepository` (FinTech payouts)

---

## 10. Firestore Collections Used
*   `users` — Shared directory user record.
*   `drivers` — Core driver configuration.
*   `driver_verifications` — Stepper documents data tracker.

---

## 11. Limitations and Next Steps
*   **Document Uploads**: While navigation correctly gates screens, actual document upload logic (National ID photo, License photo, live Camera selfie validation) is mock-only. This will be wired to Firebase Storage and database updates in **Prompt 4**.

---

## 12. Flutter Analyze/Test Results
*   `flutter analyze`: **`No issues found!`**
*   `flutter test`: **`All tests passed!`**
