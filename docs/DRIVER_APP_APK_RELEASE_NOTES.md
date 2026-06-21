# TheRain Driver App - APK Release Notes

Controlled testing notes and instructions for the TheRain Driver application.

---

## 1. General Release Info
- **App Name**: TheRain Driver
- **Version**: `1.0.0+1` (Version Name: `1.0.0`, Version Code: `1`)
- **Build Mode**: Debug / Controlled QA Testing
- **APK Output Path**: `build/app/outputs/flutter-apk/app-debug.apk`

---

## 2. Configuration Status
- **Firebase Project**: Connected to project `therain-production`.
- **Google Maps**: Active (Android maps SDK loaded via Gradle manifest placeholders).
- **Permissions Required**: Fine Location, Coarse Location, Camera, Internet, Network State.

---

## 3. Included Features
1. **Authentication**: Email/password registration and sign-in.
2. **Registration Stepper**: Driver details, ID upload, License upload, live selfie capture, and pending submission locks.
3. **Dashboard & Map**: Google Maps interface, center-camera telemetry, and location permissions gating.
4. **Online Toggle**: Verified status gates (unverified/suspended users cannot go online) and live GPS coordinates logging.
5. **Ride Matching**: Active trip incoming overlays, accepted/declined transaction gates, and ride status updates.
6. **Active Trip Loop**: Pickup routing, passenger location tracking streams, arrival confirmations, ongoing transits, and completion earnings settlement.
7. **Utility Subsystems**: Wallet balance streams, withdrawal request submissions, support ticket submissions, notifications pushes, and panic SOS triggers.

---

## 4. Known Limitations
- Wallet cash-outs write a `'pending'` record under `/driver_transactions` for manual administrative matching (Cloud Functions settlement requires backend deployment).
- Deep polyline route drawing uses direct connector mapping fallback if Google Directions API credentials are not active.

---

## 5. Test Driver Signup & Log In
1. Open the app and tap **Sign Up**.
2. Register a new email (e.g. `test-driver@therain.com`).
3. Complete Step 1 of the Verification Stepper (Profile and Vehicle details).
4. Upload mock card images for Steps 2 and 3 (National ID, Licence).
5. Snap a selfie using the camera on Step 4 and click **Submit** on Step 5.
6. The app will land on the **Verification Pending** screen.

---

## 6. How to Approve the Driver from Firebase Console
To allow the test driver to access the Dashboard and go online:
1. Open the Firebase Console for your project `therain-production`.
2. Go to **Firestore Database** -> **drivers** collection.
3. Select the document corresponding to the test driver's `uid`.
4. Modify the following fields:
   - `verificationStatus` = `"approved"`
   - `accountStatus` = `"active"`
   - `canReceiveRides` = `true`
5. The driver app will instantly receive the stream update, route them to the Approved landing page, and load the main Dashboard.

---

## 7. How to Create a Test Ride Request
To simulate an incoming ride request on the driver app:
1. Ensure the approved test driver is online (online toggle active on the Dashboard).
2. Go to Firestore Database -> **ride_requests** collection.
3. Create a new document with an ID (e.g., `test_request_01`) and add:
   ```json
   {
     "requestId": "test_request_01",
     "riderId": "test_rider_uid",
     "riderName": "Test Passenger",
     "riderPhone": "+237600000000",
     "pickupLocation": {
       "address": "Commercial Avenue, Bamenda",
       "lat": 5.9597,
       "lng": 10.1459
     },
     "destinationLocation": {
       "address": "Mile 2 Nkwen, Bamenda",
       "lat": 5.9850,
       "lng": 10.1680
     },
     "distanceKm": 4.2,
     "estimatedDurationMinutes": 14,
     "selectedRideType": "classic",
     "estimatedFare": 2500,
     "currency": "XAF",
     "paymentMethod": "cash",
     "status": "searching_driver",
     "assignedDriverId": "YOUR_TEST_DRIVER_UID",
     "expiresAt": Timestamp (e.g., 2 minutes in the future)
   }
   ```
4. The driver app will display the match overlay. Click **Accept** to test the trip lifecycle.

---

## 8. Bug Reporting & Target Audience
- **Bug Reporting**: Use the template located in `docs/DRIVER_APP_BUG_REPORT_TEMPLATE.md`.
- **Target Audience**: Approved QA engineers, internal development teams, and project coordinators.
- **Do Not Share With**: Public app stores, external drivers, or general riders.

---

## 9. Safety Warning
> [!CAUTION]
> This APK is for controlled testing only. Do not use it for real public ride operations until the admin dashboard, security rules, payment settlement, and live operational support are fully verified.
