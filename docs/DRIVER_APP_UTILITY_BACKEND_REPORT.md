# TheRain Driver App - Utility Backend Alignment Report

This document reports on the inspection, implementation, backend connections, and validation of the driver app's utility backend features (Earnings, Wallet, Withdrawals, Documents, Support, SOS, and Notifications).

---

## 1. Utility Files Inspected
- `lib/data/repositories/driver_wallet_repository.dart`
- `lib/data/repositories/driver_earning_repository.dart`
- `lib/data/repositories/driver_vehicle_repository.dart`
- `lib/data/repositories/driver_support_repository.dart`
- `lib/data/repositories/sos_repository.dart`
- `lib/data/repositories/driver_notification_repository.dart`
- `lib/data/models/driver_wallet.dart`
- `lib/data/models/driver_transaction.dart`
- `lib/data/models/driver_earning.dart`
- `lib/data/models/driver_vehicle.dart`
- `lib/data/models/driver_document.dart`
- `lib/data/models/support_ticket.dart`
- `lib/data/models/driver_notification.dart`
- `lib/features/earnings/screens/earnings_dashboard_screen.dart`
- `lib/features/earnings/screens/earnings_summary_screen.dart`
- `lib/features/wallet/screens/wallet_screen.dart`
- `lib/features/wallet/screens/withdraw_screen.dart`
- `lib/features/wallet/screens/withdrawal_history_screen.dart`
- `lib/features/vehicle/screens/vehicle_documents_screen.dart`
- `lib/features/vehicle/screens/add_vehicle_screen.dart`
- `lib/features/vehicle/screens/vehicle_information_screen.dart`
- `lib/features/vehicle/screens/vehicle_management_screen.dart`
- `lib/features/support/screens/report_issue_screen.dart`
- `lib/features/support/screens/emergency_screen.dart`
- `lib/features/profile/screens/edit_profile_screen.dart`
- `lib/services/driver_profile_service.dart`

---

## 2. Existing Wallet/Earnings Logic Found
- **Wallet Persistence**: Listened to real-time snapshots of the driver's wallet document in `driver_wallets/{uid}`.
- **Transactions Query**: Listened to `driver_transactions` where `driverId == uid` ordered by time.
- **Earnings Computation**: Formulated locally by aggregating transactions of the week starting from Monday.

---

## 3. Existing Document/Vehicle Logic Found
- **Stepper Verification**: Handled ID, Licence, and Selfie uploads to `driver_verifications/$uid/` during onboarding.
- **Vehicles/Documents**: Returned mock records locally in `DriverVehicleRepository`.

---

## 4. Existing Support/SOS Logic Found
- **Support Tickets**: Written under the `driver_support_tickets` collection, uploading screenshot attachments to storage.
- **SOS Panic Alerts**: Created entries in the `sos_alerts` collection containing coordinates, phone number, and user name.

---

## 5. Existing Notification Logic Found
- **Push Alerts**: Subscribed FCM tokens and monitored notifications in the `notifications` collection filtered by `userId == uid`.

---

## 6. Collections Used
- `driver_wallets` - Balances and payout details.
- `driver_transactions` - Earning entries and withdrawal logs.
- `driver_vehicles` - Registered vehicles and document statuses.
- `driver_documents` - Uploaded licensing/insurance files.
- `driver_support_tickets` - Help ticket submissions.
- `sos_alerts` - Panic alerts.
- `notifications` - User alert pushes.
- `users` - Shared account displays.
- `drivers` - Driver profiles.

---

## 7. Storage Paths Used
- `driver_documents/{uid}/{documentType}_{timestamp}.jpg` - Personal documents.
- `vehicle_documents/{uid}/{vehicleId}/{documentType}_{timestamp}.jpg` - Vehicle documents.
- `driver_support_tickets/{uid}/{ticketId}/screenshot.jpg` - Support attachments.

---

## 8. Screens Connected or Repaired
1. **Earnings Dashboard**: Integrated period-based (`Daily`, `Weekly`, `Monthly`) aggregations. Rendered dynamic Mon-Sun chart heights using Mon-Sun daily totals. Replaced hardcoded online time with formatted minutes.
2. **Earnings Summary**: Bound details dynamically and connected "View Transactions" to history.
3. **Wallet**: Upgraded to real-time streams using `StreamBuilder`. Added pending balance visualization.
4. **Withdrawal**: Checked available balance and minimum limit, routed real payout details card, and submitted pending withdrawal requests with exact success message.
5. **Withdrawal History**: Changed to real-time stream.
6. **Vehicle Documents**: Converted to `StatefulWidget`. Picked and uploaded documents with custom expiry dates.
7. **Add Vehicle**: Integrated controllers to submit a new pending vehicle to Firestore.
8. **Vehicle Details**: Configured route arguments to render selected vehicle.
9. **Support Tickets**: Updated success snackbar and handled upload loaders.
10. **SOS Emergency**: Configured payload coordinates, active ride ID reference, status, and custom messages.
11. **Edit Profile**: Saved name, email, and phone asynchronous changes to both `users` and `drivers` collections.

---

## 9. Security Checks Preserved
- Drivers read only their own wallets and transactions.
- Client cannot mutate balances directly.
- Document uploads default to pending; admin approval required.
- Vehicles are saved as pending and cannot be auto-approved.

---

## 10. Backend Logic Preserved
- Cloud Functions for withdrawals (`createWithdrawalRequest`) and settlements are preserved.
- Onboarding stepper upload logic remains unchanged.

---

## 11. Payment/Withdrawal Limitations
- Withdrawal requests validate against `minimumWithdrawal` and `availableToWithdraw`.
- Payout parameters rely on registered mobile numbers.

---

## 12. Rules Needed or Updated
No changes are made to the `firestore.rules` file in this prompt. The required security rule structure includes:
```javascript
match /driver_wallets/{uid} {
  allow read: if request.auth != null && request.auth.uid == uid;
}
match /driver_transactions/{id} {
  allow read: if request.auth != null && resource.data.driverId == request.auth.uid;
  allow create: if request.auth != null && request.resource.data.driverId == request.auth.uid && request.resource.data.status == 'pending';
}
```

---

## 13. Flutter Analyze/Test Results
- `flutter analyze`: **`No issues found!`**
- `flutter test`: **`All tests passed!`**

---

## 14. Recommended Final Cleanup/Testing Tasks
- Verify Firebase Storage rules allow writing to `vehicle_documents` and `driver_documents` paths for authenticated users.
- Perform end-to-end user testing of withdrawal creation with a local Firebase emulator.
