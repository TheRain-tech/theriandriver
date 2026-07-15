import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../config/firebase_config.dart';
import '../../core/utils/validators.dart';
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

  Future<void> saveNationalIdDraft({
    required String uid,
    required String nationalIdNumber,
    required String frontPath,
    required String backPath,
  }) async {
    if (!FirebaseConfig.isAvailable) return;
    final idValidator = const CameroonIdValidator();
    final batch = _db.batch();
    batch.set(_verificationRef(uid), {
      'driverId': uid,
      'nationalIdNumber': idValidator.normalize(nationalIdNumber),
      'nationalIdFrontPath': frontPath,
      'nationalIdBackPath': backPath,
      'nationalIdPhotoPath': frontPath,
      'nationalIdDocumentType': 'cameroon_national_id',
      'nationalIdValidationStatus': idValidator.validationStatus(
        nationalIdNumber,
      ),
      'nationalIdReviewNotes': null,
      'status': 'inProgress',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(
      _db.collection(FirestoreCollections.drivers).doc(uid),
      {
        'verificationStatus': 'inProgress',
        'onboardingStep': 'licence',
        'onboardingStatus': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> saveLicenceDraft({
    required String uid,
    required String licenceNumber,
    required DateTime expiryDate,
    required String photoPath,
  }) async {
    if (!FirebaseConfig.isAvailable) return;
    final batch = _db.batch();
    batch.set(_verificationRef(uid), {
      'driverId': uid,
      'driverLicenceNumber': licenceNumber.trim(),
      'driverLicenceExpiryDate': Timestamp.fromDate(expiryDate),
      'driverLicencePhotoPath': photoPath,
      'status': 'inProgress',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(
      _db.collection(FirestoreCollections.drivers).doc(uid),
      {
        'verificationStatus': 'inProgress',
        'onboardingStep': 'selfie',
        'onboardingStatus': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> saveSelfieDraft({
    required String uid,
    required String selfiePath,
  }) async {
    if (!FirebaseConfig.isAvailable) return;
    final batch = _db.batch();
    batch.set(_verificationRef(uid), {
      'driverId': uid,
      'selfiePhotoPath': selfiePath,
      'status': 'inProgress',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(
      _db.collection(FirestoreCollections.drivers).doc(uid),
      {
        'verificationStatus': 'inProgress',
        'onboardingStep': 'review',
        'onboardingStatus': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
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
        nationalIdBackPath: draft.nationalIdBackPhotoPath,
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

    final idValidator = const CameroonIdValidator();
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
        'nationalIdNumber': idValidator.normalize(draft.nationalIdNumber),
        'driverLicenceNumber': draft.driverLicenceNumber,
        'driverLicenceExpiryDate': Timestamp.fromDate(
          draft.driverLicenceExpiryDate!,
        ),
        'nationalIdFrontPath': draft.nationalIdPhotoPath,
        'nationalIdBackPath': draft.nationalIdBackPhotoPath,
        'nationalIdPhotoPath': draft.nationalIdPhotoPath,
        'nationalIdFrontUploadedAt': FieldValue.serverTimestamp(),
        'nationalIdBackUploadedAt': FieldValue.serverTimestamp(),
        'nationalIdDocumentType': 'cameroon_national_id',
        'nationalIdValidationStatus': idValidator.validationStatus(
          draft.nationalIdNumber,
        ),
        'nationalIdReviewNotes': null,
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
      }, SetOptions(merge: true));

      // Mark the driver profile as submitted and onboarding complete.
      // Deliberately does NOT write applicationStatus here: this is a merge onto an
      // already-existing document (created earlier by seedDriverProfile), and applicationStatus
      // is in firestore.rules' driverProtectedFields() - a driver cannot self-update it on an
      // existing doc (rules reject the *entire* write, not just that field, if attempted). It is
      // seeded once at document creation (seedDriverProfile) and otherwise only ever
      // backfilled/advanced server-side (node-api's applyAsDriver/approve/reject) - see
      // docs/platform/phase-6/PROFILE_LISTING_ROOT_CAUSE.md.
      transaction.set(driverRef, {
        'verificationStatus': 'pending',
        'onboardingStep': 'submitted',
        'onboardingStatus': 'submitted',
        'onboardingComplete': true,
        'accountStatus': 'pending',
        'canGoOnline': false,
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
