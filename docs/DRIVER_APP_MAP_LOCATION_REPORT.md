# TheRain Driver App - Maps & Location Tracking Audit Report

This report outlines the implementation details, routing, location telemetry, permission checks, and safety fallback mechanisms configured for the map interface.

---

## 1. Map & Location Files Inspected
- `lib/services/location_service.dart` - High-accuracy GPS positioning stream and permission gates.
- `lib/data/repositories/location_repository.dart` - Writes driver coordinates to Firestore, reads rider updates.
- `lib/services/driver_profile_service.dart` - Handles online/offline state change flows.
- `lib/features/shared/widgets/map_preview_card.dart` - Map visual interface utilizing the Google Maps Flutter SDK with canvas fallback.
- `lib/features/rides/widgets/ride_common.dart` - Coordinates maps and rider telemetry updates.
- `lib/features/rides/screens/trip_details_screen.dart` - Completed trip historic preview details screen.

---

## 2. Existing Map Logic Found
- **MapPreviewCard**: Centers camera dynamically around driver and route coordinates. If Google Maps is unavailable or API credentials are not set up, it renders a custom vector paint road fallback detailing general routes.
- **RideTrackingMap**: Listens to active rider coordinates via streams during active ride states.
- **AndroidManifest.xml & Info.plist**: Configured with internet, coarse location, fine location, and camera permissions, as well as build-time meta-data keys.

---

## 3. Google Maps Configuration Status
- Android build setups load the API Key at build time from `local.properties`, project `.env`, or System Environment variables to the Gradle `manifestPlaceholders["googleMapsApiKey"]`.
- iOS build setups map the key dynamic parameter `GOOGLE_MAPS_API_KEY` to the Runner package Plist file.
- Clean vector painting fallback occurs if the Google Maps package detects missing keys, avoiding blank screens.

---

## 4. Location Permission Flow Repaired
- Permission is checked by verifying if GPS is enabled on the device.
- Denied permissions request access via geolocator prompt alerts.
- Permanently denied permission alerts offer a settings navigation trigger button.
- All errors are captured at the service level, displaying clean dialog boxes instead of crashing the UI.

---

## 5. Online/Offline Checks Repaired
- Gating has been enhanced so that a driver **cannot** go online without active location and GPS enabled.
- The order of checks on status toggle is:
  1. Call `ensurePermission()` to check GPS services and authorization.
  2. Call `setOnline()` transaction-level profile validation to check account approval.
  3. Start location telemetry tracking.
- If tracking fails, the service reverts the database entry to offline status immediately.

---

## 6. Driver Live Location Collection & Fields Used
- **Collection**: `driver_live_locations/{uid}`
- **Written Fields**:
  - `driverId` (String): Authenticated user uid.
  - `lat` / `latitude` (Double): Coordinate values.
  - `lng` / `longitude` (Double): Coordinate values.
  - `heading` (Double): Device movement direction angle.
  - `speed` (Double): Movement velocity.
  - `accuracy` (Double): Horizontal GPS deviation range in meters.
  - `isOnline` (Boolean): Online state flag.
  - `isAvailable` (Boolean): Available to match rides (`isOnline && currentRideId == null`).
  - `isOnTrip` (Boolean): Active trip flag (`currentRideId != null`).
  - `vehicleType` (String): Driver vehicle class.
  - `supportedRideTypes` (List<String>): List containing vehicle type categorization.
  - `currentRideId` (String / Null): Current ride document key if on trip.
  - `updatedAt` (Timestamp): Firestore server time representation.

---

## 7. Driver Location Update Behavior
- Initial coordinates are published immediately upon going online.
- Subsequent updates are throttled using Geolocator's `distanceFilter: 10` meters configuration to prevent excessive database writes and preserve battery life.
- Updates stop immediately when the driver goes offline or signs out of the app.

---

## 8. Rider/Customer Tracking Behavior
- Telemetry reads from the `rider_live_locations/{riderId}` collection.
- Reads are constrained: they are only active during trip lifecycles involving the driver, and are stopped and disposed immediately when a trip is finished or cancelled.

---

## 9. Route & Polyline Behavior
- Supports rendering route lines based on decoded Google Maps polyline strings.
- Implements direct-line connector fallbacks if polyline strings are absent or parsing errors are caught.

---

## 10. Error/Fallback States Added
- Native camera tracking errors are captured within try-catch blocks.
- Missing API keys or platform-specific loading issues gracefully render custom vector-painted maps rather than exposing raw warnings.

---

## 11. Security & Privacy Notes
- Drivers cannot update telemetry coordinates unless they are verified as approved in the database.
- Live coordinates are not uploaded when a driver is offline.
- Customer coordinates are accessed only inside active accepted ride contexts.

---

## 12. Flutter Analyze & Test Results
- `flutter analyze`: **`No issues found!`**
- `flutter test`: **`All tests passed!`**
