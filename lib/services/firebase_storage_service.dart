import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../config/firebase_config.dart';
import '../core/localization/driver_copy.dart';
import '../core/utils/document_image_optimizer.dart';
import '../core/utils/document_upload_policy.dart';

typedef UploadProgress = void Function(double progress);

// Below this, an image is left exactly as picked - above it, it's always run through
// DocumentImageOptimizer before upload, not only when it exceeds the 10MB hard cap. A modern
// phone photo (3-8MB) was previously uploaded untouched on a weak connection, which is the real
// cause of slow/stalled document uploads (see uploadBytes's own 10MB-only gate, now removed).
// 1.5MB keeps a document's text legible after re-encoding while meaningfully cutting upload time.
const _kProactiveCompressionThresholdBytes = 1536 * 1024;

// A transient-failure retry budget: 2 retries (3 attempts total) with a short backoff, only for
// FirebaseException codes that are genuinely worth retrying (a dropped connection, a storage-
// backend hiccup) - never for unauthorized/validation-shaped errors, where retrying wastes the
// driver's time before showing them the real, actionable reason.
const _kMaxUploadAttempts = 3;
const _kRetryableStorageCodes = {
  'network-request-failed',
  'retry-limit-exceeded',
  'unknown',
};
const _kUploadTimeout = Duration(seconds: 90);

class FirebaseStorageService {
  FirebaseStorageService({FirebaseStorage? storage})
    : _storageOverride = storage;

  final FirebaseStorage? _storageOverride;

  FirebaseStorage get _storage =>
      _storageOverride ??
      FirebaseStorage.instanceFor(
        bucket: 'gs://${FirebaseConfig.storageBucket}',
      );

  Future<String> uploadFile({
    required XFile file,
    required String path,
    UploadProgress? onProgress,
  }) async {
    final bytes = await file.readAsBytes();
    return uploadBytes(
      bytes: bytes,
      path: path,
      contentType:
          file.mimeType ?? DocumentUploadPolicy.contentTypeFor(file.name),
      onProgress: onProgress,
    );
  }

  Future<String> uploadBytes({
    required Uint8List bytes,
    required String path,
    String? contentType,
    UploadProgress? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw StateError(
        DriverCopy.current.t(
          'The selected file is empty.',
          'Le fichier sélectionné est vide.',
        ),
      );
    }
    if (!FirebaseConfig.isAvailable) {
      if (FirebaseConfig.useMockFallback) {
        onProgress?.call(1);
        return path;
      }
      throw StateError(
        DriverCopy.current.t(
          'Firebase Storage is unavailable.',
          'Le stockage Firebase est indisponible.',
        ),
      );
    }

    var bytesToUpload = bytes;
    var uploadPath = path;
    var resolvedContentType =
        contentType ?? DocumentUploadPolicy.contentTypeFor(path);
    if (resolvedContentType.startsWith('image/')) {
      if (bytesToUpload.length > DocumentUploadPolicy.maxImageBytes) {
        throw StateError(
          DriverCopy.current.t(
            'Choose an image smaller than 100 MB.',
            'Choisissez une image de moins de 100 Mo.',
          ),
        );
      }
      if (bytesToUpload.length > _kProactiveCompressionThresholdBytes) {
        try {
          bytesToUpload = await DocumentImageOptimizer.optimize(bytesToUpload);
          uploadPath = DocumentImageOptimizer.jpegPathFor(path);
          resolvedContentType = 'image/jpeg';
        } on StateError {
          // Preserve large formats such as HEIC when the Dart codec cannot transcode them, or
          // when the image was already small enough that optimize() couldn't reduce it further -
          // either way the original bytes are still valid to upload as-is below.
        }
      }
    } else if (bytesToUpload.length > DocumentUploadPolicy.maxBytes) {
      throw StateError(
        DriverCopy.current.t(
          'Choose a PDF smaller than 10 MB.',
          'Choisissez un PDF de moins de 10 Mo.',
        ),
      );
    }

    StateError? lastError;
    for (var attempt = 1; attempt <= _kMaxUploadAttempts; attempt++) {
      debugPrint(
        '[driver-storage-upload-start] path=$uploadPath bytes=${bytesToUpload.length} '
        'contentType=$resolvedContentType attempt=$attempt/$_kMaxUploadAttempts',
      );
      final task = _storage
          .ref(uploadPath)
          .putData(
            bytesToUpload,
            SettableMetadata(contentType: resolvedContentType),
          );
      final subscription = task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });

      try {
        await task.timeout(_kUploadTimeout);
        onProgress?.call(1);
        debugPrint('[driver-storage-upload-success] path=$uploadPath');
        return uploadPath;
      } on FirebaseException catch (error) {
        debugPrint(
          '[driver-storage-upload-fail] path=$uploadPath code=${error.code} '
          'message=${error.message} attempt=$attempt/$_kMaxUploadAttempts',
        );
        lastError = StateError(_friendlyStorageError(error));
        if (!_kRetryableStorageCodes.contains(error.code) ||
            attempt == _kMaxUploadAttempts) {
          throw lastError;
        }
      } on TimeoutException {
        debugPrint(
          '[driver-storage-upload-timeout] path=$uploadPath attempt=$attempt/$_kMaxUploadAttempts',
        );
        await task.cancel().catchError((_) => false);
        lastError = StateError(
          DriverCopy.current.t(
            'The upload is taking too long. Check your connection and try again.',
            'Le téléversement prend trop de temps. Vérifiez votre connexion et réessayez.',
          ),
        );
        if (attempt == _kMaxUploadAttempts) throw lastError;
      } finally {
        await subscription.cancel();
      }
      onProgress?.call(0);
      await Future.delayed(Duration(seconds: attempt));
    }
    // Unreachable - the loop above always returns or throws - but satisfies the analyzer.
    throw lastError ??
        StateError(
          DriverCopy.current.t(
            'The document upload failed. Please try again.',
            "Le téléversement du document a échoué. Veuillez réessayer.",
          ),
        );
  }

  /// A real HTTPS download URL for an already-uploaded storage [path] —
  /// needed anywhere a value is sent on to node-api as `evidenceUrls`
  /// (Joi-validated as a URI on the server), since the storage path alone
  /// isn't a URI admins/backends can resolve.
  Future<String> getDownloadUrl(String path) async {
    if (!FirebaseConfig.isAvailable) return path;
    try {
      return await _storage.ref(path).getDownloadURL();
    } on FirebaseException catch (error) {
      debugPrint(
        '[driver-storage-url-fail] path=$path code=${error.code} '
        'message=${error.message}',
      );
      throw StateError(_friendlyStorageError(error));
    }
  }

  /// Reads back the bytes of an already-uploaded storage [path]. Used to forward a document
  /// that was written straight to Firebase Storage (the driver-app's own upload path) on to
  /// node-api's own document-upload endpoint, without needing to keep the original in-memory
  /// bytes around until final submit.
  Future<Uint8List?> downloadBytes(
    String path, {
    int maxSizeBytes = DocumentUploadPolicy.maxImageBytes,
  }) async {
    if (!FirebaseConfig.isAvailable) return null;
    try {
      return await _storage.ref(path).getData(maxSizeBytes);
    } on FirebaseException catch (error) {
      debugPrint(
        '[driver-storage-download-fail] path=$path code=${error.code} '
        'message=${error.message}',
      );
      return null;
    }
  }

  String _friendlyStorageError(FirebaseException error) => switch (error.code) {
    'unauthorized' => DriverCopy.current.t(
      'Your session cannot upload this document. Sign in again and retry.',
      'Votre session ne peut pas téléverser ce document. Reconnectez-vous et réessayez.',
    ),
    'object-not-found' || 'bucket-not-found' => DriverCopy.current.t(
      'Document storage could not confirm the upload. Please retry once.',
      "Le stockage des documents n'a pas pu confirmer le téléversement. Veuillez réessayer une fois.",
    ),
    // The single most common code on a weak/dropped mobile connection - previously fell through
    // to the generic default below, which is exactly what the National ID Back upload failure
    // showed the driver instead of a real, actionable reason.
    'network-request-failed' => DriverCopy.current.t(
      'Network connection lost during upload. Check your signal and try again.',
      'Connexion réseau perdue pendant le téléversement. Vérifiez votre signal et réessayez.',
    ),
    'retry-limit-exceeded' || 'unknown' => DriverCopy.current.t(
      'The upload was interrupted. Check your connection and retry.',
      'Le téléversement a été interrompu. Vérifiez votre connexion et réessayez.',
    ),
    'canceled' => DriverCopy.current.t(
      'The upload was cancelled.',
      'Le téléversement a été annulé.',
    ),
    _ => DriverCopy.current.t(
      'The document upload failed. Please try again.',
      'Le téléversement du document a échoué. Veuillez réessayer.',
    ),
  };
}
