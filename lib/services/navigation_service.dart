import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'api_client.dart';
import 'location_service.dart';

/// One turn-by-turn instruction, decoded from node-api's `/maps/route`
/// response (maps.service.js#mapRouteResult - itself a thin, testable wrapper
/// around Google's Routes API `legs.steps`).
class NavStep {
  const NavStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.endLocation,
    required this.polylinePoints,
  });

  final String instruction;
  final String? maneuver;
  final double distanceMeters;
  final LatLng endLocation;
  final List<LatLng> polylinePoints;

  factory NavStep.fromJson(Map<String, dynamic> json) {
    final end = json['endLocation'] as Map<String, dynamic>?;
    final encoded = json['encodedPolyline']?.toString() ?? '';
    final points = encoded.isEmpty
        ? const <LatLng>[]
        : PolylinePoints.decodePolyline(
            encoded,
          ).map((p) => LatLng(p.latitude, p.longitude)).toList();
    return NavStep(
      instruction: (json['instruction']?.toString() ?? '').trim(),
      maneuver: json['maneuver']?.toString(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      endLocation: end == null
          ? const LatLng(0, 0)
          : LatLng(
              (end['latitude'] as num?)?.toDouble() ?? 0,
              (end['longitude'] as num?)?.toDouble() ?? 0,
            ),
      polylinePoints: points,
    );
  }
}

/// Snapshot of where a driver is in an active turn-by-turn session, published
/// to [NavigationService.state] after every processed GPS fix.
class DriverNavigationState {
  const DriverNavigationState({
    required this.destinationLabel,
    required this.routePolyline,
    required this.steps,
    required this.currentStepIndex,
    required this.distanceToManeuverMeters,
    required this.remainingDistanceMeters,
    required this.remainingSeconds,
    required this.isRerouting,
    required this.hasArrived,
  });

  final String destinationLabel;
  final List<LatLng> routePolyline;
  final List<NavStep> steps;
  final int currentStepIndex;
  final double distanceToManeuverMeters;
  final double remainingDistanceMeters;
  final int remainingSeconds;
  final bool isRerouting;
  final bool hasArrived;

  NavStep? get currentStep =>
      currentStepIndex < steps.length ? steps[currentStepIndex] : null;
  NavStep? get nextStep =>
      currentStepIndex + 1 < steps.length ? steps[currentStepIndex + 1] : null;
}

/// Real, in-app turn-by-turn voice navigation for the driver's own live GPS
/// position, built on the existing [LocationService.currentLocation] stream
/// (already running continuously while a driver is online, including during
/// a trip) rather than starting a second, competing location subscription.
///
/// Scope, stated plainly: this announces each maneuver once, when the driver
/// gets close enough to it (proximity-triggered), not the countdown-style
/// "in 300 meters, then in 100 meters" cadence a dedicated commercial nav
/// app uses - that needs finer-grained distance-remaining-to-next-maneuver
/// tracking along the route geometry, which is a reasonable next step but a
/// materially bigger effort than this first version. Off-route driving
/// triggers a real reroute (fresh directions request from the driver's
/// current position to the same final destination).
class NavigationService {
  NavigationService._();

  static final instance = NavigationService._();

  static const _maneuverArrivalRadiusMeters = 30.0;
  static const _finalArrivalRadiusMeters = 25.0;
  static const _offRouteThresholdMeters = 70.0;
  static const _offRouteConfirmDuration = Duration(seconds: 12);
  static const _rerouteCooldown = Duration(seconds: 20);

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<DriverNavigationState?> state = ValueNotifier(null);

  List<NavStep> _steps = const [];
  List<LatLng> _overviewPolyline = const [];
  LatLng? _finalDestination;
  String _destinationLabel = '';
  int _currentStepIndex = 0;
  bool _voiceEnabled = true;
  bool _ttsReady = false;
  DateTime? _offRouteSince;
  DateTime? _lastRerouteAt;
  bool _isRerouting = false;
  bool _active = false;

  bool get isActive => _active;

  void setVoiceEnabled(bool enabled) {
    _voiceEnabled = enabled;
    if (!enabled) _tts.stop();
  }

  Future<void> _ensureTts() async {
    if (_ttsReady) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(false);
    _ttsReady = true;
  }

  /// Starts guiding the driver from their current live position to
  /// [destination]. Call again (e.g. after pickup, to head to the dropoff)
  /// to redirect an already-active session to a new destination.
  Future<void> startNavigation({
    required LatLng destination,
    required String destinationLabel,
  }) async {
    await _ensureTts();
    _finalDestination = destination;
    _destinationLabel = destinationLabel;
    _active = true;
    _offRouteSince = null;

    final origin = LocationService.instance.currentLocation.value;
    final originLatLng = origin == null
        ? destination
        : LatLng(origin.lat, origin.lng);

    await _fetchRoute(originLatLng, destination);

    LocationService.instance.currentLocation.removeListener(_onLocationChanged);
    LocationService.instance.currentLocation.addListener(_onLocationChanged);
  }

  void stopNavigation() {
    _active = false;
    LocationService.instance.currentLocation.removeListener(_onLocationChanged);
    _steps = const [];
    _overviewPolyline = const [];
    _finalDestination = null;
    _currentStepIndex = 0;
    _offRouteSince = null;
    _tts.stop();
    state.value = null;
  }

  Future<void> _fetchRoute(LatLng origin, LatLng destination) async {
    try {
      final response = await ApiClient.instance.post(
        '/api/maps/route',
        body: {
          'origin': {'lat': origin.latitude, 'lng': origin.longitude},
          'destination': {
            'lat': destination.latitude,
            'lng': destination.longitude,
          },
        },
      );
      final data = response is Map
          ? (response['data'] as Map? ?? response)
          : <String, dynamic>{};
      final legs = (data['legs'] as List?) ?? const [];
      final firstLeg = legs.isNotEmpty
          ? legs.first as Map<String, dynamic>
          : <String, dynamic>{};
      final steps = ((firstLeg['steps'] as List?) ?? const [])
          .map((step) => NavStep.fromJson(step as Map<String, dynamic>))
          .where((step) => step.polylinePoints.isNotEmpty)
          .toList(growable: false);
      final encodedOverview = data['encodedPolyline']?.toString() ?? '';
      final overview = encodedOverview.isEmpty
          ? steps.expand((s) => s.polylinePoints).toList()
          : PolylinePoints.decodePolyline(
              encodedOverview,
            ).map((p) => LatLng(p.latitude, p.longitude)).toList();

      _steps = steps.isNotEmpty
          ? steps
          : [
              NavStep(
                instruction: 'Head to $_destinationLabel',
                maneuver: null,
                distanceMeters: 0,
                endLocation: destination,
                polylinePoints: overview.isNotEmpty
                    ? overview
                    : [origin, destination],
              ),
            ];
      _overviewPolyline = overview;
      _currentStepIndex = 0;
      _isRerouting = false;
      _publishState();
      if (_steps.isNotEmpty) _speak(_steps.first.instruction);
    } catch (error) {
      debugPrint('[navigation] route fetch failed: $error');
      _isRerouting = false;
    }
  }

  void _onLocationChanged() {
    if (!_active) return;
    final location = LocationService.instance.currentLocation.value;
    final destination = _finalDestination;
    if (location == null || destination == null || _steps.isEmpty) return;
    final current = LatLng(location.lat, location.lng);

    final distanceToFinalDestination = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      destination.latitude,
      destination.longitude,
    );
    if (distanceToFinalDestination <= _finalArrivalRadiusMeters) {
      _speak('You have arrived at $_destinationLabel');
      stopNavigation();
      return;
    }

    final currentStep = _steps[_currentStepIndex];
    final distanceToManeuver = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      currentStep.endLocation.latitude,
      currentStep.endLocation.longitude,
    );
    if (distanceToManeuver <= _maneuverArrivalRadiusMeters &&
        _currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
      _speak(_steps[_currentStepIndex].instruction);
    }

    _checkOffRoute(current);
    _publishState();
  }

  void _checkOffRoute(LatLng current) {
    if (_isRerouting || _steps.isEmpty) return;
    final currentStep = _steps[_currentStepIndex];
    final distanceToRoute = _distanceToPolyline(
      current,
      currentStep.polylinePoints,
    );
    if (distanceToRoute <= _offRouteThresholdMeters) {
      _offRouteSince = null;
      return;
    }
    _offRouteSince ??= DateTime.now();
    final offRouteFor = DateTime.now().difference(_offRouteSince!);
    if (offRouteFor < _offRouteConfirmDuration) return;

    final lastReroute = _lastRerouteAt;
    if (lastReroute != null &&
        DateTime.now().difference(lastReroute) < _rerouteCooldown) {
      return;
    }

    final destination = _finalDestination;
    if (destination == null) return;
    _isRerouting = true;
    _lastRerouteAt = DateTime.now();
    _offRouteSince = null;
    _speak('Recalculating route');
    _publishState();
    unawaited(_fetchRoute(current, destination));
  }

  double _distanceToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return 0;
    var minDistance = double.infinity;
    for (final vertex in polyline) {
      final distance = Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        vertex.latitude,
        vertex.longitude,
      );
      if (distance < minDistance) minDistance = distance;
    }
    return minDistance;
  }

  void _speak(String text) {
    if (!_voiceEnabled || text.isEmpty) return;
    unawaited(_tts.speak(text));
  }

  void _publishState() {
    final location = LocationService.instance.currentLocation.value;
    final destination = _finalDestination;
    var remainingDistance = 0.0;
    if (location != null && destination != null) {
      remainingDistance = Geolocator.distanceBetween(
        location.lat,
        location.lng,
        destination.latitude,
        destination.longitude,
      );
    }
    final currentStep = _currentStepIndex < _steps.length
        ? _steps[_currentStepIndex]
        : null;
    final distanceToManeuver = (location != null && currentStep != null)
        ? Geolocator.distanceBetween(
            location.lat,
            location.lng,
            currentStep.endLocation.latitude,
            currentStep.endLocation.longitude,
          )
        : 0.0;
    // ~30 km/h average urban speed assumption for a rough ETA when the
    // backend doesn't return a fresh duration for a rerouted/partial leg.
    final remainingSeconds = (remainingDistance / (30 * 1000 / 3600)).round();

    state.value = DriverNavigationState(
      destinationLabel: _destinationLabel,
      routePolyline: _overviewPolyline,
      steps: _steps,
      currentStepIndex: _currentStepIndex,
      distanceToManeuverMeters: distanceToManeuver,
      remainingDistanceMeters: remainingDistance,
      remainingSeconds: remainingSeconds,
      isRerouting: _isRerouting,
      hasArrived: false,
    );
  }
}
