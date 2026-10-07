import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:theraindriver/core/utils/route_snapping.dart';

// A raw GPS fix is routinely a few meters off the real road; snapToRoute is what makes the 3D
// vehicle marker sit on the known route instead of floating beside it, within a bounded tolerance
// so a driver who has genuinely left the route is never shown on a line they are not on.
void main() {
  // A short, roughly east-west route near Douala - short enough that the equirectangular
  // approximation inside snapToRoute is accurate to well under a meter.
  const a = LatLng(4.0500, 9.7000);
  const b = LatLng(4.0500, 9.7020);
  const c = LatLng(4.0520, 9.7020);
  final route = [a, b, c];

  test('a point already on a segment snaps to itself', () {
    const onSegment = LatLng(4.0500, 9.7010);
    final snapped = snapToRoute(onSegment, route);
    expect(snapped, isNotNull);
    expect(
      Geolocator.distanceBetween(
        onSegment.latitude,
        onSegment.longitude,
        snapped!.latitude,
        snapped.longitude,
      ),
      lessThan(1),
    );
  });

  test('a point slightly off a straight segment snaps onto it, not past either end', () {
    // ~20m north of the midpoint of a-b, which runs east-west.
    const offRoute = LatLng(4.05018, 9.7010);
    final snapped = snapToRoute(offRoute, route);
    expect(snapped, isNotNull);
    // Snapped latitude should land back on the a-b segment's own latitude (4.0500), not drift
    // toward b-c's latitude.
    expect(snapped!.latitude, closeTo(4.0500, 0.0001));
    expect(snapped.longitude, closeTo(9.7010, 0.0005));
  });

  test('picks the nearer of two segments meeting at a vertex', () {
    // Just past the b/c corner, closer to the b-c leg than continuing along a-b.
    const nearCorner = LatLng(4.0505, 9.7021);
    final snapped = snapToRoute(nearCorner, route);
    expect(snapped, isNotNull);
    // Should land on the b-c leg (longitude close to 9.7020), not back on a-b.
    expect(snapped!.longitude, closeTo(9.7020, 0.0003));
  });

  test('a point well beyond the tolerance returns null instead of a fake snap', () {
    const farAway = LatLng(4.2000, 9.9000);
    expect(snapToRoute(farAway, route), isNull);
  });

  test('a point just inside a custom tolerance snaps; just outside it does not', () {
    const point = LatLng(4.0500, 9.7010);
    // Perpendicular offset in latitude of roughly 50m from the a-b segment.
    final offsetPoint = LatLng(point.latitude + 0.00045, point.longitude);
    final distanceMeters = Geolocator.distanceBetween(
      point.latitude,
      point.longitude,
      offsetPoint.latitude,
      offsetPoint.longitude,
    );

    expect(
      snapToRoute(offsetPoint, route, toleranceMeters: distanceMeters + 5),
      isNotNull,
    );
    expect(
      snapToRoute(offsetPoint, route, toleranceMeters: distanceMeters - 5),
      isNull,
    );
  });

  test('fewer than 2 route points never snaps', () {
    expect(snapToRoute(a, const []), isNull);
    expect(snapToRoute(a, const [a]), isNull);
  });
}
