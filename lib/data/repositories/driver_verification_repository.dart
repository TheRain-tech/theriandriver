import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../config/firebase_config.dart';
import '../../firebase/firestore_collections.dart';
import '../../services/registration_draft_service.dart';
import '../mock/mock_driver_verification.dart';
import '../models/app_enums.dart';
import '../models/driver_verification.dart';

class DriverVerificationRepository {
  DriverVerificationRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;
  DriverVerification _mockVerification = mockDriverVerification;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _verificationRef(String uid) =>
      _db.collection(FirestoreCollections.driverVerifications).doc(uid);

  Future<DriverVerification?> getVerification(String uid) async {
    if (FirebaseConfig.useMockFallback) return _mockVerification;
    if (!FirebaseConfig.isAvailable) return null;
    final snapshot = await _verificationRef(uid).get();
    final data = snapshot.data();
    return data == null ? null : DriverVerification.fromMap(data, snapshot.id);
  }

  Stream<DriverVerification?> watchVerification(String uid) {
    if (FirebaseConfig.useMockFallback) {
      return Stream.value(_mockVerification);
    }
    if (!FirebaseConfig.isAvailable) return Stream.value(null);
    return _verificationRef(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null
          ? null
          : DriverVerification.fromMap(data, snapshot.id);
    });
  }

  Future<void> submit({
    required String uid,
    required RegistrationDraft draft,
  }) async {
    if (!draft.isComplete) {
      throw StateError('Complete every verification step before submitting.');
    }

    if (FirebaseConfig.useMockFallback) {
      _mockVerification = DriverVerification(
        id: uid,
        driverId: uid,
        status: DriverVerificationStatus.pending,
        nationalIdNumber: draft.nationalIdNumber,
        licenceNumber: draft.driverLicenceNumber,
        licenceExpiry: draft.driverLicenceExpiryDate,
        nationalIdPath: draft.nationalIdPhotoPath,
        licencePath: draft.driverLicencePhotoPath,
        selfiePath: draft.selfiePhotoPath,
        submittedAt: DateTime.now(),
      );
      return;
    }
    if (!FirebaseConfig.isAvailable) {
      throw StateError('Firebase is unavailable.');
    }

    debugPrint('[driver-verification-submit-start] uid=$uid');

    final verificationRef = _verificationRef(uid);
    final driverRef = _db.collection(FirestoreCollections.drivers).doc(uid);

    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(verificationRef);
      final previousCount =
          (existing.data()?['resubmissionCount'] as num?)?.toInt() ?? 0;
      final wasResubmission =
          existing.data()?['status'] == 'rejected' ||
          existing.data()?['status'] == 'resubmissionRequired';

      // set() without merge replaces the doc entirely.
      // Firestore rules treat this as UPDATE when the doc exists, CREATE
      // when it doesn't. Both paths are covered by the updated rules.
      transaction.set(verificationRef, {
        'driverId': uid,
        'nationalIdNumber': draft.nationalIdNumber,
        'driverLicenceNumber': draft.driverLicenceNumber,
        'driverLicenceExpiryDate': Timestamp.fromDate(
          draft.driverLicenceExpiryDate!,
        ),
        'nationalIdPhotoPath': draft.nationalIdPhotoPath,
        'driverLicencePhotoPath': draft.driverLicencePhotoPath,
        'selfiePhotoPath': draft.selfiePhotoPath,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedBy': null,
        'reviewedAt': null,
        'rejectionReason': null,
        'resubmissionCount': wasResubmission
            ? previousCount + 1
            : previousCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mark the driver profile as submitted and onboarding complete.
      transaction.set(driverRef, {
        'verificationStatus': 'pending',
        'onboardingStep': 'submitted',
        'onboardingComplete': true,
        'canReceiveRides': false,
        'isOnline': false,
        'status': 'offline',
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    debugPrint('[driver-verification-submit-success] uid=$uid');
  }
}
