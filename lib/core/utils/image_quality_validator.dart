import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Result of a quick client-side quality check on a captured/picked photo,
/// run before it's ever uploaded — rejects the three failure modes camera
/// verification is required to catch: blank, corrupted, and too-dark.
class ImageQualityResult {
  const ImageQualityResult._({required this.isValid, this.reason});

  final bool isValid;
  final String? reason;

  static const ok = ImageQualityResult._(isValid: true);

  factory ImageQualityResult.rejected(String reason) =>
      ImageQualityResult._(isValid: false, reason: reason);
}

abstract final class ImageQualityValidator {
  /// Empty/corrupted files are rejected outright; a valid image is then
  /// downsampled and its average luminance measured to catch a
  /// blank/near-black frame (lens covered, capture in the dark, etc.).
  /// Kept deliberately cheap (a small thumbnail decode) so it runs
  /// synchronously fast on-device right after capture, before any upload.
  static ImageQualityResult validate(
    Uint8List bytes, {
    int minBytes = 2048,
    double minAverageLuminance = 18,
  }) {
    if (bytes.isEmpty) {
      return ImageQualityResult.rejected(
        'The captured image was empty. Please try again.',
      );
    }
    if (bytes.length < minBytes) {
      return ImageQualityResult.rejected(
        'The captured image looks corrupted or too small. Please retake it.',
      );
    }

    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      return ImageQualityResult.rejected(
        'This image could not be read. Please retake the photo.',
      );
    }

    final thumbnail = img.copyResize(
      decoded,
      width: decoded.width > 64 ? 64 : decoded.width,
    );

    double total = 0;
    var count = 0;
    for (var y = 0; y < thumbnail.height; y++) {
      for (var x = 0; x < thumbnail.width; x++) {
        final pixel = thumbnail.getPixel(x, y);
        // Standard perceptual luminance weighting.
        total += 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        count++;
      }
    }
    final averageLuminance = count == 0 ? 0.0 : total / count;

    if (averageLuminance < minAverageLuminance) {
      return ImageQualityResult.rejected(
        'This photo looks too dark to use. Please retake it in better lighting.',
      );
    }

    return ImageQualityResult.ok;
  }
}
