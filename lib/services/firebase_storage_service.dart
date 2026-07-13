import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../config/firebase_config.dart';

typedef UploadProgress = void Function(double progress);

class FirebaseStorageService {
  FirebaseStorageService({FirebaseStorage? storage})
    : _storageOverride = storage;

  final FirebaseStorage? _storageOverride;

  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  Future<String> uploadFile({
    required XFile file,
    required String path,
    UploadProgress? onProgress,
  }) async {
    final bytes = await file.readAsBytes();
    return uploadBytes(bytes: bytes, path: path, onProgress: onProgress);
  }

  Future<String> uploadBytes({
    required Uint8List bytes,
    required String path,
    UploadProgress? onProgress,
  }) async {
    if (bytes.isEmpty) throw StateError('The selected image is empty.');
    if (!FirebaseConfig.isAvailable) {
      if (FirebaseConfig.useMockFallback) {
        onProgress?.call(1);
        return path;
      }
      throw StateError('Firebase Storage is unavailable.');
    }

    final task = _storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final subscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });

    try {
      await task;
      onProgress?.call(1);
      return path;
    } on FirebaseException catch (error) {
      throw StateError(
        error.message ?? 'The image upload failed. Please try again.',
      );
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
    return _storage.ref(path).getDownloadURL();
  }
}
