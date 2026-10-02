import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../config/firebase_config.dart';
import '../core/utils/document_image_optimizer.dart';
import '../core/utils/document_upload_policy.dart';

typedef UploadProgress = void Function(double progress);

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
    if (bytes.isEmpty) throw StateError('The selected file is empty.');
    if (!FirebaseConfig.isAvailable) {
      if (FirebaseConfig.useMockFallback) {
        onProgress?.call(1);
        return path;
      }
      throw StateError('Firebase Storage is unavailable.');
    }

    var bytesToUpload = bytes;
    var uploadPath = path;
    var resolvedContentType =
        contentType ?? DocumentUploadPolicy.contentTypeFor(path);
    if (resolvedContentType.startsWith('image/')) {
      if (bytesToUpload.length > DocumentUploadPolicy.maxImageBytes) {
        throw StateError('Choose an image smaller than 100 MB.');
      }
      if (bytesToUpload.length > DocumentUploadPolicy.maxBytes) {
        try {
          bytesToUpload = await DocumentImageOptimizer.optimize(bytesToUpload);
          uploadPath = DocumentImageOptimizer.jpegPathFor(path);
          resolvedContentType = 'image/jpeg';
        } on StateError {
          // Preserve large formats such as HEIC when the Dart codec cannot transcode them.
        }
      }
    } else if (bytesToUpload.length > DocumentUploadPolicy.maxBytes) {
      throw StateError('Choose a PDF smaller than 10 MB.');
    }
    debugPrint(
      '[driver-storage-upload-start] path=$uploadPath bytes=${bytesToUpload.length} '
      'contentType=$resolvedContentType',
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
      await task;
      onProgress?.call(1);
      debugPrint('[driver-storage-upload-success] path=$uploadPath');
      return uploadPath;
    } on FirebaseException catch (error) {
      debugPrint(
        '[driver-storage-upload-fail] path=$uploadPath code=${error.code} '
        'message=${error.message}',
      );
      throw StateError(_friendlyStorageError(error));
    } finally {
      await subscription.cancel();
    }
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
    'unauthorized' =>
      'Your session cannot upload this document. Sign in again and retry.',
    'object-not-found' || 'bucket-not-found' =>
      'Document storage could not confirm the upload. Please retry once.',
    'retry-limit-exceeded' ||
    'unknown' => 'The upload was interrupted. Check your connection and retry.',
    'canceled' => 'The upload was cancelled.',
    _ => 'The document upload failed. Please try again.',
  };
}
