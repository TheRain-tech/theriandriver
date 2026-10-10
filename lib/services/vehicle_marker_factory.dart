import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Offset, Paint, Rect;
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The vehicle visuals which are already approved and bundled with the Driver
/// app. Unknown values intentionally return no branded marker so the UI never
/// claims a driver has a vehicle category that the backend did not provide.
enum TheRainVehicleKind { car, bike, delivery, school, ambulance }

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
    'ambulance' || 'emergency' || 'medical_transport' => TheRainVehicleKind.ambulance,
    _ => null,
  };
}

/// Discrete zoom buckets rather than continuous per-frame scaling: large
/// enough steps that `VehicleMarkerFactory`'s cache (keyed by width/height)
/// only ever regenerates a handful of bitmaps per session, not one per GPS
/// update or camera-drag frame.
// Deliberately flat past zoom 16.5: a marker that keeps growing with zoom the way the map itself
// does reads as a large promotional sticker rather than a GPS position indicator - the exact
// complaint navigation apps like Waze avoid by keeping their vehicle icon's screen-space size
// roughly constant once zoomed in close enough to navigate by. Mirrors therian's own
// vehicle_marker_factory.dart#vehicleMarkerScaleForZoom (same tuning, two separate apps).
double vehicleMarkerScaleForZoom(double zoom) {
  if (zoom <= 12) return 0.6;
  if (zoom <= 13.5) return 0.75;
  if (zoom <= 15) return 0.88;
  if (zoom <= 16.5) return 1.0;
  if (zoom <= 18) return 1.1;
  return 1.2;
}

/// Creates small, cached Google Maps vehicle descriptors. The descriptor is
/// visual only: callers continue to supply its position and bearing directly
/// from the device's real GPS stream.
class VehicleMarkerFactory {
  VehicleMarkerFactory._();

  static const _assetFor = <TheRainVehicleKind, String>{
    TheRainVehicleKind.car: 'assets/vehicles/therain_car.png',
    TheRainVehicleKind.bike: 'assets/vehicles/therain_bike.png',
    TheRainVehicleKind.delivery: 'assets/vehicles/delivery.png',
    TheRainVehicleKind.school: 'assets/vehicles/school.png',
    TheRainVehicleKind.ambulance: 'assets/vehicles/therain_ambulance.png',
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
    // The source PNG is already transparent (background removed) - draw it
    // straight onto the otherwise-empty canvas, "contain"-scaled, with no
    // card/shadow/border behind it, so the vehicle sits directly over the map.
    final sourceWidth = source.width.toDouble();
    final sourceHeight = source.height.toDouble();
    final scale = (canvasWidth / sourceWidth < canvasHeight / sourceHeight)
        ? canvasWidth / sourceWidth
        : canvasHeight / sourceHeight;
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, sourceWidth, sourceHeight),
      Rect.fromCenter(
        center: Offset(canvasWidth / 2, canvasHeight / 2),
        width: sourceWidth * scale,
        height: sourceHeight * scale,
      ),
      Paint()..filterQuality = ui.FilterQuality.high,
    );

    final image = await recorder.endRecording().toImage(widthPx, heightPx);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
  }
}
