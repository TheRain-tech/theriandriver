# TheRain Driver App - Driver Verification Backend & Approval Flow Report

This report outlines the verification backend logic, document uploads, live selfie capture, and real-time approval status flows.

---

## 1. Verification Files Inspected
*   `lib/services/driver_verification_service.dart` - Service listening to active validation states.
*   `lib/services/registration_draft_service.dart` - Temporary draft memory layer.
*   `lib/services/firebase_storage_service.dart` - Raw byte and file upload layer using Firebase Storage API.
*   `lib/services/storage_upload_service.dart` - Gallery document photo picking controller.
*   `lib/data/repositories/driver_verification_repository.dart` - Repository handling verification submission transactions to Firestore.
*   `lib/features/verification/screens/national_id_verification_screen.dart` - ID number validation and photo upload.
*   `lib/features/verification/screens/driver_licence_verification_screen.dart` - License details validation and photo upload.
*   `lib/features/verification/screens/live_selfie_verification_screen.dart` - Front camera liveness selfie controller.
*   `lib/features/verification/screens/verification_review_submit_screen.dart` - Document completeness validation and final submit actions.
*   `lib/features/verification/screens/verification_pending_screen.dart` - Real-time approval listener.
*   `lib/features/verification/screens/verification_approved_screen.dart` - Welcome landing screen.

---

## 2. Existing Verification Logic Found
*   **Draft Builder**: State is held locally inside `RegistrationDraft` so that progress is maintained between screens.
*   **File Stream**: Uploads images directly to Firebase Storage with local upload progress trackers (`onProgress`).
*   **Submission Transaction**: Writes document credentials to the `driver_verifications` collection and locks verification status to `'pending'` and `canReceiveRides` to `false` in a multi-write atomic batch transaction.

---

## 3. Screens Connected to Backend
*   **National ID Upload**: Connected to `StorageUploadService` (Gallery Picker) and `FirebaseStorageService` (Storage Uploader).
*   **Licence Upload**: Connected to future-only Date picker verification and `FirebaseStorageService`.
*   **Live Selfie**: Connected to the `camera` lens initializer, taking snapshot raw bytes and uploading directly to Storage.
*   **Review & Submit**: Connected to `DriverVerificationRepository.submit` atomic batch transaction.
*   **Pending Screen**: Connected to the real-time `watchProfile(uid)` listener. Redirection to the approved view or resubmission stepper executes immediately upon status change.

---

## 4. Firestore Collections Used
*   `users` — Core registry.
*   `drivers` — Driver profile metadata (requires `verificationStatus == 'approved'` and `canReceiveRides == true` before allowing online transitions).
*   `driver_verifications` — Document numbers, Storage file paths, and audit details.

---

## 5. Storage Paths Used
*   `driver_verifications/$uid/national_id.jpg` - Image of National ID card.
*   `driver_verifications/$uid/driver_licence.jpg` - Image of Driver's license.
*   `driver_verifications/$uid/selfie.jpg` - Captured live verification selfie.

---

## 6. Verification Statuses Used
*   `notStarted` - Initial state.
*   `inProgress` - Active configuration.
*   `pending` - Submitted and in review.
*   `approved` - Allowed to go online.
*   `rejected` - Account disabled (must resubmit).
*   `resubmissionRequired` - Resubmission stepper enabled.

---

## 7. Upload Flow Implemented/Repaired
*   Validated that upload boxes block multiple simultaneous taps while uploading.
*   Progress bars accurately show bytes transferred percentage.
*   Firestore only saves relative Storage path references (e.g. `driver_verifications/$uid/selfie.jpg`) rather than vulnerable public URL formats, maintaining data privacy.

---

## 8. Live Selfie Behavior
*   Uses `camera` package with `CameraLensDirection.front`.
*   Bypasses gallery upload (camera capture only) to prevent spoofing.
*   Disposes camera resources on application lifecycle pauses (resumed cameras are safely re-initialized).

---

## 9. Pending/Approved/Rejected Behavior
*   Pending drivers are redirected to the pending view via route guards.
*   Approval updates verificationStatus in real-time, routing the driver immediately to the approved success page.
*   Rejection renders the administrator reason text and unlocks the "Update Verification Documents" route, transitioning status back to `'inProgress'` upon resubmission.

---

## 10. Security Checks Preserved
*   **Online Blocking**: Drivers cannot change status to online unless `verificationStatus == 'approved'` and `canReceiveRides == true`.
*   **Dashboard Gating**: `AppRoutes._guard` blocks unverified access.

---

## 11. Rules Needed or Updated
*   **Firestore Security Rules** (`firestore.rules`):
    *   Drivers can write profile updates only if `verificationStatus` transitions from `notStarted` -> `inProgress` or `inProgress` -> `pending`. Bypassing status directly to `approved` from the mobile client is strictly blocked.
    *   Drivers can only read/write their own verification records under `driver_verifications/$userId`.
*   **Storage Security Rules** (`storage.rules`):
    *   Restricts folder writes under `driver_verifications/$userId/` to the authenticated owner.
    *   Requires uploaded files to be under 5MB and limits filenames strictly to `national_id.jpg`, `driver_licence.jpg`, and `selfie.jpg`.

---

## 12. Backend Logic Preserved
*   No modifications were made to Google Maps key structures, active ride tracking streams, wallet cash-outs, or transaction systems.

---

## 13. Limitations and Next Steps
*   **Telemetry Telecommunication**: Real map drawing, location tracking streams, and foreground background update streams will be configured in **Prompt 5**.

---

## 14. Flutter Analyze/Test Results
*   `flutter analyze`: **`No issues found!`**
*   `flutter test`: **`All tests passed!`**
