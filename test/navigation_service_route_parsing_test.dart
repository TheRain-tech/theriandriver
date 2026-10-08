import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:theraindriver/services/navigation_service.dart';

// Regression test for a same-day backend/frontend contract mismatch: node-api's
// maps.service.js#computeRouteAlternatives (commit 4db5798) changed POST /api/maps/route's
// response from a single route object with `legs` at the top level to `{ routes: [...] }`, for a
// planned driver road-choice picker - but the matching client-side fix was never actually pushed.
// Left as-is, every real route fetch would silently find zero legs/steps and fall back to a bare
// straight-line "head to destination" instruction - the driver's entire turn-by-turn screen
// (instructions, maneuver icons, the real road polyline) would go dark while still technically
// "working." parseRouteResponse is the pure, directly-testable extraction of that parsing logic.
void main() {
  const origin = LatLng(4.05, 9.7);
  const destination = LatLng(4.1, 9.75);

  // A real, valid Google-encoded polyline (the canonical algorithm-documentation example) -
  // NavStep.fromJson decodes every step's own polyline and drops any step whose decode fails
  // or comes back empty, so a made-up placeholder string (e.g. "enc_step_1") silently decodes
  // to nothing and would make every test below false-positive into the fallback path.
  const validEncodedPolyline = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

  Map<String, dynamic> routesEnvelope(List<Map<String, dynamic>> routes) => {
    'routes': routes,
  };

  Map<String, dynamic> sampleRoute({String polyline = validEncodedPolyline}) => {
    'distanceMeters': 7423,
    'duration': '900s',
    'encodedPolyline': polyline,
    'legs': [
      {
        'distanceMeters': 7423,
        'duration': '900s',
        'steps': [
          {
            'instruction': 'Head east toward N6',
            'maneuver': 'STRAIGHT',
            'distanceMeters': 300,
            'endLocation': {'latitude': 4.06, 'longitude': 9.71},
            'encodedPolyline': validEncodedPolyline,
          },
          {
            'instruction': 'Turn left onto Food Market Rd',
            'maneuver': 'TURN_LEFT',
            'distanceMeters': 150,
            'endLocation': {'latitude': 4.07, 'longitude': 9.72},
            'encodedPolyline': validEncodedPolyline,
          },
        ],
      },
    ],
  };

  test(
    "today's real backend shape ({ routes: [...] }) is parsed into real turn-by-turn steps, not the straight-line fallback",
    () {
      final data = routesEnvelope([sampleRoute()]);

      final parsed = parseRouteResponse(
        data,
        origin: origin,
        destination: destination,
        destinationLabel: 'Bamenda',
      );

      expect(parsed.steps.length, 2);
      expect(parsed.steps[0].instruction, 'Head east toward N6');
      expect(parsed.steps[1].instruction, 'Turn left onto Food Market Rd');
      expect(parsed.steps[1].maneuver, 'TURN_LEFT');
    },
  );

  test(
    'the OLD shape (legs at the top level, no routes[]) no longer matches - this pins the current contract so a future backend change is caught here, not silently in production',
    () {
      final oldShapeData = sampleRoute(); // legs directly at top level, no "routes" wrapper

      final parsed = parseRouteResponse(
        oldShapeData,
        origin: origin,
        destination: destination,
        destinationLabel: 'Bamenda',
      );

      // routes[] is absent, so this now falls back - proving the old shape is NOT
      // what today's backend sends, and confirming exactly why navigation went dark.
      expect(parsed.steps.length, 1);
      expect(parsed.steps.first.instruction, 'Head to Bamenda');
    },
  );

  test('multiple route alternatives - the first (best) one is always used', () {
    final data = routesEnvelope([
      sampleRoute(),
      {
        ...sampleRoute(),
        'legs': [
          {
            'distanceMeters': 9000,
            'duration': '1200s',
            'steps': [
              {
                'instruction': 'Take the longer alternative road',
                'maneuver': 'STRAIGHT',
                'distanceMeters': 9000,
                'endLocation': {'latitude': 4.2, 'longitude': 9.8},
                'encodedPolyline': validEncodedPolyline,
              },
            ],
          },
        ],
      },
    ]);

    final parsed = parseRouteResponse(
      data,
      origin: origin,
      destination: destination,
      destinationLabel: 'Bamenda',
    );

    expect(parsed.steps.first.instruction, 'Head east toward N6');
  });

  test('an empty routes list falls back to a single straight-line instruction, not a crash', () {
    final parsed = parseRouteResponse(
      routesEnvelope(const []),
      origin: origin,
      destination: destination,
      destinationLabel: 'Bamenda',
    );

    expect(parsed.steps.length, 1);
    expect(parsed.steps.first.polylinePoints, [origin, destination]);
  });

  test('a step with no decodable polyline is dropped rather than shown as a broken instruction', () {
    final data = routesEnvelope([
      {
        'encodedPolyline': validEncodedPolyline,
        'legs': [
          {
            'steps': [
              {
                'instruction': 'Valid step',
                'maneuver': 'STRAIGHT',
                'distanceMeters': 100,
                'endLocation': {'latitude': 4.06, 'longitude': 9.71},
                'encodedPolyline': validEncodedPolyline,
              },
              {
                'instruction': 'Step with no polyline',
                'maneuver': 'STRAIGHT',
                'distanceMeters': 50,
                'endLocation': {'latitude': 4.065, 'longitude': 9.715},
                'encodedPolyline': '',
              },
            ],
          },
        ],
      },
    ]);

    final parsed = parseRouteResponse(
      data,
      origin: origin,
      destination: destination,
      destinationLabel: 'Bamenda',
    );

    expect(parsed.steps.length, 1);
    expect(parsed.steps.first.instruction, 'Valid step');
  });
}
