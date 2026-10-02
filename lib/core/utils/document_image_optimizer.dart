
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'document_upload_policy.dart';

abstract final class DocumentImageOptimizer {
  static Future<Uint8List> optimize(Uint8List bytes) async {
    final optimized = await compute(_optimizeImage, bytes);
    if (optimized == null ||
        optimized.length >= DocumentUploadPolicy.maxBytes) {
      throw StateError(
        'This image could not be reduced enough to upload. Choose a clearer, smaller image.',
      );
    }
    return optimized;
  }

  static String jpegPathFor(String path) {
    final separator = path.lastIndexOf('/');
    final extension = path.lastIndexOf('.');
    if (extension > separator) return '${path.substring(0, extension)}.jpg';
    return '$path.jpg';
  }
}

Uint8List? _optimizeImage(Uint8List bytes) {
  img.Image? source;
  try {
    source = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (source == null || source.width == 0 || source.height == 0) return null;

  var working = source;
  final longestSide = working.width > working.height
      ? working.width
      : working.height;
  if (longestSide > 5000) {
    working = img.copyResize(
      working,
      width: (working.width * 5000 / longestSide).round(),
      height: (working.height * 5000 / longestSide).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  for (var resizeAttempt = 0; resizeAttempt < 10; resizeAttempt++) {
    for (final quality in const [90, 84, 78, 72, 66, 60, 54]) {
      final encoded = img.encodeJpg(working, quality: quality);
      if (encoded.length < DocumentUploadPolicy.maxBytes) {
        return Uint8List.fromList(encoded);
      }
    }

    final currentLongestSide = working.width > working.height
        ? working.width
        : working.height;
    if (currentLongestSide <= 900) break;
    working = img.copyResize(
      working,
      width: (working.width * 0.8).round().clamp(1, working.width),
      height: (working.height * 0.8).round().clamp(1, working.height),
      interpolation: img.Interpolation.cubic,
    );
  }
  return null;
}
