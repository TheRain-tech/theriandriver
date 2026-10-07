import 'dart:typed_data';

import '../localization/driver_copy.dart';

abstract final class DocumentUploadPolicy {
  static const maxBytes = 10 * 1024 * 1024;
  static const maxImageBytes = 100 * 1024 * 1024;
  static const imageExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };
  static const documentExtensions = <String>{...imageExtensions, 'pdf'};

  static String extensionFor(String fileName) {
    final cleanName = fileName.split('?').first.replaceAll('\\', '/');
    final dot = cleanName.lastIndexOf('.');
    if (dot < 0 || dot == cleanName.length - 1) return '';
    return cleanName.substring(dot + 1).toLowerCase();
  }

  static bool isPdf(String fileName) => extensionFor(fileName) == 'pdf';

  static bool isSupported(String fileName, {bool allowPdf = true}) {
    final allowed = allowPdf ? documentExtensions : imageExtensions;
    return allowed.contains(extensionFor(fileName));
  }

  static String contentTypeFor(String fileName) =>
      switch (extensionFor(fileName)) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'heif' => 'image/heif',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };

  static void validate({
    required String fileName,
    required Uint8List bytes,
    bool allowPdf = true,
  }) {
    if (bytes.isEmpty) {
      throw StateError(
        DriverCopy.current.t(
          'The selected file is empty. Choose another file.',
          'Le fichier sélectionné est vide. Choisissez un autre fichier.',
        ),
      );
    }
    final sizeLimit = isPdf(fileName) ? maxBytes : maxImageBytes;
    if (bytes.length > sizeLimit) {
      throw StateError(
        isPdf(fileName)
            ? DriverCopy.current.t(
                'Choose a PDF smaller than 10 MB.',
                'Choisissez un PDF de moins de 10 Mo.',
              )
            : DriverCopy.current.t(
                'Choose an image smaller than 100 MB.',
                'Choisissez une image de moins de 100 Mo.',
              ),
      );
    }
    if (!isSupported(fileName, allowPdf: allowPdf)) {
      throw StateError(
        allowPdf
            ? DriverCopy.current.t(
                'Use a JPG, JPEG, PNG, WEBP, HEIC, HEIF, or PDF file.',
                'Utilisez un fichier JPG, JPEG, PNG, WEBP, HEIC, HEIF ou PDF.',
              )
            : DriverCopy.current.t(
                'Use a JPG, JPEG, PNG, WEBP, HEIC, or HEIF image.',
                'Utilisez une image JPG, JPEG, PNG, WEBP, HEIC ou HEIF.',
              ),
      );
    }
  }
}
