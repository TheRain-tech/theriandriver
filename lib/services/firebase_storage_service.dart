import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../config/firebase_config.dart';
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

    final resolvedContentType =
        contentType ?? DocumentUploadPolicy.contentTypeFor(path);
    debugPrint(
      '[driver-storage-upload-start] path=$path bytes=${bytes.length} '
      'contentType=$resolvedContentType',
    );
    final task = _storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: resolvedContentType));
    final subscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });

    try {
      await task;
      onProgress?.call(1);
      debugPrint('[driver-storage-upload-success] path=$path');
      return path;
    } on FirebaseException catch (error) {
      debugPrint(
        '[driver-storage-upload-fail] path=$path code=${error.code} '
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
