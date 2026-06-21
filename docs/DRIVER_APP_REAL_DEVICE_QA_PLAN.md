# TheRain Driver App - Real-Device QA Plan

This document outlines the real-device testing plan, test scenarios, test data parameters, and controlled QA procedures for the TheRain Driver application.

---

## 1. Test Objective
To validate the stability, security rules, location tracking, and ride lifecycle flows of the TheRain Driver App on physical devices under a live Firebase and Google Maps environment.

## 2. Required Devices
- **Primary**: Android physical device (API Level 24+ / Android 7.0+).
- **Secondary**: Firebase Console dashboard / Admin panel web interface (for document approvals and simulating rider requests).

## 3. Required Firebase Setup
- **Firebase Auth**: Email/password authentication provider enabled.
- **Cloud Firestore**: Database collections created: `users`, `drivers`, `driver_verifications`, `rides`, `ride_requests`, `driver_live_locations`, `rider_live_locations`, `driver_wallets`, `driver_transactions`, `driver_support_tickets`, `sos_alerts`, `notifications`.
- **Firebase Storage**: Folders: `driver_verifications`, `driver_documents`, `vehicle_documents`, `driver_support_tickets`.
- **Security Rules**: `firestore.rules` and `storage.rules` deployed to enforce gated permissions.

## 4. Required Google Maps Setup
- Google Maps SDK for Android enabled in the Google Cloud Console.
- API Key configured and restricted (by package name `com.therain.driver` and SHA-1 fingerprint).

## 5. Required Test Accounts
- **Test Driver Email**: `test-driver@therain.com`
- **Test Driver Password**: `TestPassword123` (Ensure password complies with standard strength criteria).

## 6. Required Firestore Test Data
- Test driver profile in `drivers/{uid}`.
- Test rider profile in `users/{riderUid}`.
- Test ride requests in `ride_requests/{rideRequestId}`.

---

## 7. Test Scenarios

### Scenario 1: Authentication & Onboarding Stepper
1. **Action**: Launch the app, sign up with test credentials.
2. **Action**: Proceed to step 1 (Profile Setup), trim and capitalize inputs (e.g. plate number `nw 234 aa` -> `NW 234 AA`). Save.
3. **Action**: Proceed to step 2 (ID Document), upload card image.
4. **Action**: Proceed to step 3 (Driver License), enter details, pick license expiration date, and upload licence image.
5. **Action**: Proceed to step 4 (Live Selfie), trigger front camera, snap a portrait, and save.
6. **Action**: Proceed to step 5 (Review & Submit), check fields, and submit.
7. **Expected Result**: Stepper progresses cleanly. Firestore creates `/drivers/{uid}` with `verificationStatus: 'pending'` and `/driver_verifications/{uid}` containing all details and Storage paths. App shows "Verification Pending" screen.

### Scenario 2: Verification Approval Redirect
1. **Action**: With the app resting on the "Verification Pending" screen, open Firebase Console.
2. **Action**: Navigate to `drivers/{uid}` and manually set:
   - `verificationStatus` = `"approved"`
   - `accountStatus` = `"active"`
   - `canReceiveRides` = `true`
3. **Expected Result**: The app's real-time stream listener intercepts the profile change and automatically routes the driver to the "Verification Approved" screen, then to the Dashboard.

### Scenario 3: Driver Online/Offline & Live Location Telemetry
1. **Action**: Tap the "Go Online" toggle on the Dashboard.
2. **Action**: Confirm location permission prompt. Toggles GPS off first to test error gating, then toggles GPS on.
3. **Action**: Tap "Go Offline" to terminate tracking.
4. **Expected Result**: Going online updates `/drivers/{uid}` -> `isOnline: true`, `status: 'online'`, and creates `/driver_live_locations/{uid}` with current GPS coordinates, `isOnline: true`, `isAvailable: true`. Going offline terminates the Geolocator tracking stream and updates database online flags to `false`. Logout updates status to offline.

### Scenario 4: Simulating Ride Request & Acceptance
1. **Action**: Put the driver online.
2. **Action**: In Firestore, create a document in `ride_requests/test_ride_request_01` representing a search query:
   - `assignedDriverId` = `"CURRENT_TEST_DRIVER_UID"`
   - `status` = `"searching_driver"`
   - `expiresAt` = Future timestamp (+2 minutes)
3. **Action**: Confirm the driver app displays the ride request overlay with fare, pickup, and dropoff address.
4. **Action**: Tap "Accept" on the request screen.
5. **Expected Result**: A Firestore transaction updates `/ride_requests/test_ride_request_01` to `status: 'driver_assigned'` and creates `/rides/{rideId}`. Driver document gets `currentRideId: rideId` and status toggles to `busy`. App routes to "Go To Pickup".

### Scenario 5: Ride Lifecycle Transitions
1. **Action**: Tap "Arrived at Pickup".
2. **Expected Result**: Status updates to `'driver_arrived'`. App shows "Pickup Confirmed".
3. **Action**: Tap "Start Trip".
4. **Expected Result**: Status updates to `'in_progress'`. App shows "Trip In Progress".
5. **Action**: Tap "End Trip".
6. **Expected Result**: Status updates to `'completed'`. Driver `currentRideId` is cleared, status toggles back to `'online'`. Earnings are settled (via development mock transaction fallback in debug mode).

### Scenario 6: Rider and Driver Cancellations
1. **Action**: Accept a new ride request to enter the active trip loop.
2. **Action**: In Firestore, set `/rides/{rideId}` status to `'cancelled_by_rider'`.
3. **Expected Result**: Driver app immediately pops a cancellation dialog and redirects the driver back to the dashboard safely.
4. **Action**: Accept another request, tap "Cancel Ride" in the app, select a cancellation reason, and submit.
5. **Expected Result**: Status is updated to `'cancelled_by_driver'`, cancellation reason is stored in the database, and driver returns to the dashboard.

### Scenario 7: Financial Dashboard & Payout Requests
1. **Action**: Navigate to Wallet screen.
2. **Expected Result**: Wallet loads real-time balance.
3. **Action**: Tap "Withdraw", input amount less than 5000 XAF, and check validation. Input amount within balance and submit.
4. **Expected Result**: Client blocks withdrawals below 5000 XAF. Submitting valid amount writes a pending transaction log in `driver_transactions` with status `'pending'` (driver cannot edit this transaction to `'completed'`).

### Scenario 8: Support Tickets & SOS Emergency Alerts
1. **Action**: Navigate to Help Center, submit support ticket.
2. **Expected Result**: `/driver_support_tickets` entry is created with ticket details.
3. **Action**: Tap the SOS icon, trigger panic alert.
4. **Expected Result**: `/sos_alerts` entry is created with current coordinates, driver details, and active ride ID (if on trip).

### Scenario 9: Error & Offline Resiliency
1. **Action**: Disable Internet on the device.
2. **Expected Result**: Try to perform auth or database writes. App displays friendly dialog: `"Check your internet connection and try again."` instead of throwing raw socket exceptions.

---

## 8. Expected vs. Actual Results
| Scenario | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- |
| S1: Auth & Onboarding Stepper | All stepper forms submit cleanly, files uploaded. | Stepper passes verification steps and uploads images to Storage. | **Pass** |
| S2: Verification Approval | Real-time redirect to dashboard on status update. | Redirection triggers instantly upon Firestore status modification. | **Pass** |
| S3: Online/Offline & Telemetry | Gps gates prevent unverified access. Locations write. | GPS permission gate blocks online status until granted; writes to `/driver_live_locations/{uid}` successfully. | **Pass** |
| S4: Ride Request Acceptance | Request modal pops, accepts via transaction, blocks race. | Overlay loads details, accept transaction commits successfully. | **Pass** |
| S5: Ride Lifecycle Transitions | Arriving -> Arrived -> In Progress -> Completed. | Correct statuses are written; transitions work cleanly. | **Pass** |
| S6: Cancellations | Rider cancellation exits trip. Driver cancellation writes reason. | Stream listener exits immediately on rider cancel; driver cancel stores reason correctly. | **Pass** |
| S7: Wallet & Payouts | Streams balance. Validates limit. Creates pending txn. | Balance and history load; limits checked; pending txn written safely. | **Pass** |
| S8: Support & SOS Alerts | Creates ticket and SOS documents. | Firestore records are written under `driver_support_tickets` and `sos_alerts`. | **Pass** |
| S9: Offline Gating | Graceful error prompts. | Friendly messages shown instead of platform/socket stack traces. | **Pass** |

## 9. Bug Log Table
| Bug ID | Description | Severity | Fix Made |
| :--- | :--- | :--- | :--- |
| B1 | `firestore.rules` checked legacy ride status strings (`'accepted'`, `'arrived'`), causing writes to fail. | Critical | Aligned `firestore.rules` to match the official status codes. |
| B2 | `acceptRideRequest` transaction did not save `paymentMethod` field, defaulting database reads to cash. | High | Saved `paymentMethod` in `rideData` during acceptance. |
| B3 | Unnecessary import of `firebase_core` in `auth_service.dart` caused analyzer compile warning. | Low | Removed the duplicate import. |

## 10. APK Readiness Checklist
- [x] No hardcoded secrets in production code or `.env`.
- [x] Google Maps API key loaded securely via build config.
- [x] Permissions (`INTERNET`, `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) configured in Manifest.
- [x] Analyzer returns clean (`No issues found!`).
- [x] All widget and unit tests pass (`All tests passed!`).
- [x] Debug APK builds successfully.

## 11. Final Testing Conclusion
The TheRain Driver App complies with all security guidelines and backend contracts. The APK is ready to share for controlled testing.
