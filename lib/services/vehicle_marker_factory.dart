import 'dart:ui' as ui;

import 'package:flutter/material.dart'
    show Color, Colors, Offset, Paint, PaintingStyle, Rect, RRect, Radius;
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';

/// The vehicle visuals which are already approved and bundled with the Driver
/// app. Unknown values intentionally return no branded marker so the UI never
/// claims a driver has a vehicle category that the backend did not provide.
enum TheRainVehicleKind { car, bike, delivery, school }

TheRainVehicleKind? theRainVehicleKindFor(String? value) {
  final normalized = value
      ?.trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
  return switch (normalized) {
    'classic' ||
    'comfort' ||
    'vip' ||
    'xl' ||
    'car' ||
    'ride' ||
    'premium' ||
    'sedan' ||
    'suv' => TheRainVehicleKind.car,
    'bike' || 'motorbike' || 'motorcycle' => TheRainVehicleKind.bike,
    'delivery' ||
    'delivery_van' ||
    'van' ||
    'parcel' => TheRainVehicleKind.delivery,
    'school' ||
    'school_transport' ||
    'school_bus' ||
    'bus' => TheRainVehicleKind.school,
    _ => null,
  };
}

/// Creates small, cached Google Maps vehicle descriptors. The descriptor is
/// visual only: callers continue to supply its position and bearing directly
/// from the device's real GPS stream.
class VehicleMarkerFactory {
  VehicleMarkerFactory._();

  static const _assetFor = <TheRainVehicleKind, String>{
    TheRainVehicleKind.car: 'assets/asset (1).png',
    TheRainVehicleKind.bike: 'assets/asset (7).png',
    TheRainVehicleKind.delivery: 'assets/asset (8).png',
    TheRainVehicleKind.school: 'assets/asset (2).png',
  };

  static final Map<String, BitmapDescriptor> _cache = {};
  static final Map<String, Future<BitmapDescriptor>> _pending = {};

  static Future<BitmapDescriptor?> forRideOrVehicleType(
    String? rideOrVehicleType, {
    required double devicePixelRatio,
    double width = 90,
    double height = 74,
  }) {
    final kind = theRainVehicleKindFor(rideOrVehicleType);
    if (kind == null) return Future.value(null);
    return forKind(
      kind,
      devicePixelRatio: devicePixelRatio,
      width: width,
      height: height,
    );
  }

  static Future<BitmapDescriptor> forKind(
    TheRainVehicleKind kind, {
    required double devicePixelRatio,
    double width = 90,
    double height = 74,
  }) {
    final cacheKey =
        '${kind.name}:${devicePixelRatio.toStringAsFixed(2)}:$width:$height';
    final cached = _cache[cacheKey];
    if (cached != null) return Future.value(cached);
    return _pending.putIfAbsent(cacheKey, () async {
      final marker = await _render(
        _assetFor[kind]!,
        devicePixelRatio: devicePixelRatio,
        width: width,
        height: height,
      );
      _cache[cacheKey] = marker;
      _pending.remove(cacheKey);
      return marker;
    });
  }

  static Future<BitmapDescriptor> _render(
    String assetPath, {
    required double devicePixelRatio,
    required double width,
    required double height,
  }) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final source = (await codec.getNextFrame()).image;
    final widthPx = (width * devicePixelRatio).round();
    final heightPx = (height * devicePixelRatio).round();
    final canvasWidth = widthPx.toDouble();
    final canvasHeight = heightPx.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
    );
    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        canvasWidth * .04,
        canvasHeight * .06,
        canvasWidth * .92,
        canvasHeight * .82,
      ),
      Radius.circular(canvasHeight * .24),
    );

    canvas.drawRRect(
      card.shift(Offset(0, canvasHeight * .10)),
      Paint()
        ..color = const Color(0x33071A66)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7),
    );
    canvas.drawRRect(card, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(card);
    final sourceWidth = source.width.toDouble();
    final sourceHeight = source.height.toDouble();
    final scale = (card.width / sourceWidth < card.height / sourceHeight)
        ? card.width / sourceWidth
        : card.height / sourceHeight;
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, sourceWidth, sourceHeight),
      Rect.fromCenter(
        center: card.center,
        width: sourceWidth * scale,
        height: sourceHeight * scale,
      ),
      Paint()..filterQuality = ui.FilterQuality.high,
    );
    canvas.restore();
    canvas.drawRRect(
      card,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = canvasHeight * .035,
    );

    final image = await recorder.endRecording().toImage(widthPx, heightPx);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
  }
}
