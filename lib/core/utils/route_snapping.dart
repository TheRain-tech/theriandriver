import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// A raw GPS fix is routinely a few meters off the actual road (urban canyon, consumer-GPS noise),
// which is the "randomly placed off the road" look drivers flagged. Snapping onto the nearest point
// of an ALREADY-KNOWN route polyline fixes that for free - no paid Roads API call needed - but only
// within this tolerance: beyond it, the driver has genuinely left the suggested route (a real
// detour, a stale/wrong route) and showing their real GPS position is more honest than snapping
// them onto a line they are not actually on.
const kRouteSnapToleranceMeters = 75.0;

/// Nearest point to [point] on any segment of [route], or null when [route] has fewer than 2
/// points or the nearest point is further than [toleranceMeters] - callers fall back to the raw
/// GPS point in that case rather than show a fake "on the road" position.
LatLng? snapToRoute(
  LatLng point,
  List<LatLng> route, {
  double toleranceMeters = kRouteSnapToleranceMeters,
}) {
  if (route.length < 2) return null;
  LatLng? best;
  var bestDistanceMeters = double.infinity;
  for (var i = 0; i < route.length - 1; i++) {
    final projected = _projectOntoSegment(point, route[i], route[i + 1]);
    final distance = Geolocator.distanceBetween(
      point.latitude,
      point.longitude,
      projected.latitude,
      projected.longitude,
    );
    if (distance < bestDistanceMeters) {
      bestDistanceMeters = distance;
      best = projected;
    }
  }
  return (best != null && bestDistanceMeters <= toleranceMeters) ? best : null;
}

// Projects [point] onto the segment [a]-[b] using a local equirectangular approximation
// (longitude scaled by cos(latitude)) - accurate enough for the short, tens-of-meters segments a
// decoded Google polyline is made of, without pulling in a full geodesy library for this.
LatLng _projectOntoSegment(LatLng point, LatLng a, LatLng b) {
  final cosLat = math.cos(a.latitude * math.pi / 180);
  final ax = a.longitude * cosLat, ay = a.latitude;
  final bx = b.longitude * cosLat, by = b.latitude;
  final px = point.longitude * cosLat, py = point.latitude;

  final dx = bx - ax, dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) return a;

  final t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(
    0.0,
    1.0,
  );
  final x = ax + t * dx;
  final y = ay + t * dy;
  return LatLng(y, x / cosLat);
}
