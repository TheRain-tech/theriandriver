# TheRain Driver App - Ride Request & Trip Lifecycle Audit Report

This report outlines the implementation details, status mappings, stream-based active trip listeners, and error handling flows configured to align the Driver application with the Rider App backend.

---

## 1. Ride Files Inspected
- `lib/firebase/firestore_collections.dart` - Official database status constants.
- `lib/data/repositories/ride_repository.dart` - Transaction-level ride database transitions.
- `lib/data/models/driver_trip.dart` - Local serialization and state mapping.
- `lib/features/rides/screens/new_ride_request_screen.dart` - Accept/Decline user choices screen.
- `lib/features/rides/screens/go_to_pickup_screen.dart` - Driver transit navigation screen.
- `lib/features/rides/screens/pickup_confirmed_screen.dart` - Arrival verification screen.
- `lib/features/rides/screens/trip_in_progress_screen.dart` - Active journey screen.
- `lib/features/rides/screens/trips_history_screen.dart` - Filterable completed trip history lists.
- `lib/services/auth_service.dart` - Startup routing and session recovery guards.

---

## 2. Existing Ride Logic Found
- **Race Condition Prevention**: `acceptRideRequest` runs in a transaction checking if `status == 'searching_driver'` and `assignedDriverId == currentUid` before committing.
- **Trip Recovery**: Startup guards check driver's `currentRideId` and `currentRideStatus` in database, restoring screen states automatically on boot/resume.

---

## 3. Ride Collections Used
- `ride_requests` - Broadcasted opportunities.
- `rides` - Confirmed matched bookings.
- `drivers` - Driver availability, status, and active ride reference keys.
- `driver_activity_logs` - Audit logs for declined requests.

---

## 4. Ride Statuses Found
The official Rider App backend status strings are:
- `draft`
- `fare_estimated`
- `searching_driver`
- `requested_specific_driver`
- `driver_assigned`
- `driver_rejected`
- `request_timeout`
- `driver_arriving`
- `driver_arrived`
- `in_progress`
- `completed`
- `cancelled_by_rider`
- `cancelled_by_driver`
- `no_driver_found`
- `payment_pending`
- `paid`
- `payment_failed`

---

## 5. Status Mappings Used
Constants inside `RideStatuses` were updated to point to the official Rider App status values:
- `searching` -> `'searching_driver'`
- `accepted` -> `'driver_assigned'`
- `driverArriving` -> `'driver_arriving'`
- `arrived` -> `'driver_arrived'`
- `ongoing` -> `'in_progress'`
- `completed` -> `'completed'`
- `cancelled` -> `'cancelled_by_driver'` (or reads both `'cancelled_by_rider'` and `'cancelled_by_driver'`).
- `expired` -> `'request_timeout'`

---

## 6. Incoming Request Listener Behavior
- Subscribes via real-time stream queries in `DriverDashboardScreen`.
- Listens strictly for documents where `assignedDriverId == currentUid` and `status == 'searching_driver'`.
- Filters out expired requests locally based on the `expiresAt` timestamp.

---

## 7. Accept/Reject Behavior
- **Accept Ride**: Disables buttons to prevent double-matching, checks that driver does not already have an active ride assignment, updates statuses in transaction, links the location stream ride identifier, and navigates.
- **Reject Ride**: Unassigns driver in transaction to return the ride back to matching pool, saves audit logs under `driver_activity_logs`, and preserves online availability.

---

## 8. Driver Assigned/Arriving/Arrived Behavior
- Acceptance sets database status to `driver_assigned`.
- Transitioning to pickup sets status to `driver_arriving`.
- Tapping arrival updates status to `driver_arrived` and timestamps the arrival.

---

## 9. Start Trip Behavior
- Tapping "Start Trip" on `PickupConfirmedScreen` transitions status to `in_progress`, stores the start time, and routes the app to `TripInProgressScreen`.

---

## 10. Complete Trip Behavior
- Tapping "End Trip" requires confirmation, transitions status to `completed`, resets driver profile ride reference values, and routes the driver to `TripCompletedScreen`.

---

## 11. Cancellation Behavior
- Driver cancellation requires selecting a reason from a dialog.
- The reason is persisted in both the `rides` and `ride_requests` collections under `cancellationReason`.
- Status is updated to `cancelled_by_driver` and driver reference is cleared.

---

## 12. Active Ride Recovery Behavior
- Startup session routing loads driver profile references on resume/launch.
- Correct screen routing is restored:
  - `'driver_assigned'` / `'driver_arriving'` -> `GoToPickupScreen`
  - `'driver_arrived'` -> `PickupConfirmedScreen`
  - `'in_progress'` -> `TripInProgressScreen`

---

## 13. Rider Cancellation Handling
- Active ride screens subscribe to real-time `watchRide(rideId)` document streams.
- If status transitions to `'cancelled_by_rider'` or `'cancelled_by_driver'`, the app pops a clean warning dialog, clears local active ride states, and returns the driver back to the dashboard safely.

---

## 14. Backend Logic Preserved
- All Firestore transactions, Cloud Functions payments settlement, and security rules logic remain fully intact and operational.

---

## 15. Security Checks Preserved
- Approved status checks before going online.
- Double assignment block validations.
- Isolation of database reads to owner documents.

---

## 16. Limitations and Next Steps
- Trip rating submission works locally; this can be extended to write back to a reviews collection in later stages.

---

## 17. Flutter Analyze/Test Results
- `flutter analyze`: **`No issues found!`**
- `flutter test`: **`All tests passed!`**
