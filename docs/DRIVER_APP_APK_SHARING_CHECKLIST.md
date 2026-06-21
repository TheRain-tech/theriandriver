# TheRain Driver App - APK Sharing Checklist

Before sharing the build with testers, verify that all checkboxes compile and pass under controlled testing.

---

### Phase 1: Build & Package Health
- [x] 1. Static code analysis completed (`flutter analyze` returned zero errors).
- [x] 2. Unit and widget test suites passed (`flutter test` returned all tests passed).
- [x] 3. Debug APK compiles successfully (`flutter build apk --debug` succeeded).
- [x] 4. App installs cleanly on physical Android device without compilation or manifest errors.
- [x] 5. Application opens fresh without startup runtime crashes.

### Phase 2: Configuration & Identity Checks
- [x] 6. App label is set to `"TheRain Driver"` in the Android Manifest.
- [x] 7. Application package namespace is configured to `com.therain.driver`.
- [x] 8. Version code and name are incremented correctly (`1.0.0+1`).
- [x] 9. Google Maps API key is securely loaded via build config variables (no hardcoded keys in Dart UI).
- [x] 10. Core permissions (`INTERNET`, `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) are declared.
- [x] 11. `.env` and client services are completely audited (no service account JSONs or private admin tokens).

### Phase 3: Core Functional Smoke Tests
- [x] 12. Firebase Authentication works (signing up maps user to Auth and Firestore).
- [x] 13. Verification stepper uploads ID, License, and front-camera-only selfie to Storage.
- [x] 14. Real-time redirect triggers cleanly once profile status is set to `'approved'` in the database.
- [x] 15. Gps permission guards block online toggling if Location/GPS services are turned off.
- [x] 16. Online telemetry coordinates stream writes cleanly to `/driver_live_locations/{uid}`.
- [x] 17. Incoming ride matching overlays load detail fields (fares, addresses) and accept via transactions.
- [x] 18. Trip transitions (`arriving` -> `arrived` -> `in_progress` -> `completed`) execute cleanly.
- [x] 19. Wallet history, withdrawals validation, and SOS panic alerts commit records to Firestore.
- [x] 20. Logout stops the Geolocator background service and signs out of FirebaseAuth cleanly.

---

### Sharing Protocol
- Tester access is restricted to approved internal QA engineers.
- Bug report template is distributed alongside release notes.
