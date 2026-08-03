import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/config/firebase_config.dart';
import 'package:theraindriver/core/utils/document_upload_policy.dart';
import 'package:theraindriver/firebase_options.dart';

void main() {
  test('production Firebase options use the existing application bucket', () {
    expect(
      DefaultFirebaseOptions.android.storageBucket,
      FirebaseConfig.storageBucket,
    );
    expect(FirebaseConfig.storageBucket, 'therain-production-rider-assets');
  });

  test('document MIME types follow the real file extension', () {
    expect(
      DocumentUploadPolicy.contentTypeFor('licence.PDF'),
      'application/pdf',
    );
    expect(
      DocumentUploadPolicy.contentTypeFor('national-id.jpeg'),
      'image/jpeg',
    );
    expect(DocumentUploadPolicy.contentTypeFor('inspection.png'), 'image/png');
    expect(DocumentUploadPolicy.contentTypeFor('vehicle.webp'), 'image/webp');
  });

  test('valid images and PDFs up to 10 MB are accepted', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    expect(
      () =>
          DocumentUploadPolicy.validate(fileName: 'licence.pdf', bytes: bytes),
      returnsNormally,
    );
    expect(
      () => DocumentUploadPolicy.validate(
        fileName: 'national-id.heic',
        bytes: bytes,
      ),
      returnsNormally,
    );
  });

  test('PDF is rejected for image-only capture fields', () {
    expect(
      () => DocumentUploadPolicy.validate(
        fileName: 'selfie.pdf',
        bytes: Uint8List.fromList([1]),
        allowPdf: false,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('unsupported and oversized documents are rejected locally', () {
    expect(
      () => DocumentUploadPolicy.validate(
        fileName: 'document.exe',
        bytes: Uint8List.fromList([1]),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DocumentUploadPolicy.validate(
        fileName: 'document.pdf',
        bytes: Uint8List(DocumentUploadPolicy.maxBytes + 1),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
