import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/models/live_location.dart';
import '../data/repositories/location_repository.dart';
import 'api_client.dart';

class LocationAccessException implements Exception {
  const LocationAccessException(this.message, {this.permanentlyDenied = false});

  final String message;
  final bool permanentlyDenied;

  @override
  String toString() => message;
}

class LocationService {
  LocationService._();

  static final instance = LocationService._();

  final LocationRepository _repository = LocationRepository();
  final ValueNotifier<LiveLocation?> currentLocation = ValueNotifier(null);
  StreamSubscription<Position>? _positionSubscription;
  String? _trackingUid;
  String? _currentRideId;
  String? _vehicleType;
  DateTime? _lastPersistedAt;

  // The position stream's distanceFilter (10m, below) alone doesn't cap write frequency - a
  // driver moving continuously in traffic can still cross 10m every 1-2 seconds. This adds a
  // time-based floor on top of it so Firestore writes stay close to what the live map actually
  // needs (~1 update/2-3s), without touching the distance filter itself.
  static const _minPersistInterval = Duration(seconds: 3);

  bool get isTracking => _positionSubscription != null;

  Future<LiveLocation> getCurrentLocation() async {
    await ensurePermission();
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return _fromPosition(position, isOnline: isTracking);
  }

  // Shows the driver's real position on the dashboard map preview as soon as the app opens,
  // instead of the generic fallback coordinate, without implying they're online - that still
  // requires the explicit swipe-to-go-online action, which is what actually starts continuous
  // tracking and backend writes via startDriverTracking. Best-effort: a driver who hasn't granted
  // location yet, or whose fix times out, simply keeps seeing the dashboard's own fallback view.
  Future<void> showLocationPreview() async {
    if (isTracking) return;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      currentLocation.value = _fromPosition(position, isOnline: false);
    } catch (_) {
      // Best-effort only - the dashboard map keeps whatever it already had.
    }
  }

  Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationAccessException(
        'Turn on device location services to go online.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationAccessException(
        'Location permission is needed to receive rides and show navigation.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationAccessException(
        'Location permission is blocked. Enable it in device settings to go '
        'online.',
        permanentlyDenied: true,
      );
    }
    // "While in use" alone stops the position stream the moment this app leaves the foreground -
    // exactly what happens when the driver opens Google Maps/Waze for turn-by-turn directions
    // (Android's own ForegroundNotificationConfig above keeps the stream alive regardless, but
    // iOS has no such override: without "Always", the rider's live map goes stale as soon as an
    // external navigation app is opened). geolocator presents the OS's own upgrade prompt here;
    // declining it is never treated as a hard failure; whileInUse still lets the driver go
    // online and track normally in the foreground.
    if (permission == LocationPermission.whileInUse) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> startDriverTracking({
    required String uid,
    String? currentRideId,
    String? vehicleType,
  }) async {
    await ensurePermission();
    await _positionSubscription?.cancel();
    _trackingUid = uid;
    _currentRideId = currentRideId;
    _vehicleType = vehicleType;
    // A driver going online again after being offline should get an immediate, unThrottled
    // position write rather than inheriting a stale throttle window from their last session.
    _lastPersistedAt = null;

    final initial = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    await _publish(initial);

    // A rider mid-ride expects to see the driver's dot creep along the road even on foot or in
    // slow traffic - 10m meant the GPS stream itself never fired for any movement smaller than
    // that, so the map looked frozen well within what a rider would consider "not updating."
    // _minPersistInterval (3s) already caps how often a fix is actually written, independent of
    // how often the sensor fires, so lowering this doesn't meaningfully change write volume.
    //
    // On Android specifically, without a foreground service Android's Doze/App Standby kills this
    // stream a short time after the screen locks or the app backgrounds - this was the real cause
    // behind both ride matching going stale after ~13 minutes idle and the live-tracking map
    // appearing frozen: the position stream had simply stopped firing, so currentLocation (and the
    // driver_live_locations doc it feeds) never updated again. foregroundNotificationConfig keeps
    // the stream alive the same way every real ride-hailing driver app does, via a persistent
    // "you're online" notification - see AndroidManifest.xml's FOREGROUND_SERVICE_LOCATION comment.
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 3,
            intervalDuration: const Duration(seconds: 3),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'TheRain Driver is online',
              notificationText: 'Sharing your live location while you\'re online or on a trip.',
              notificationIcon: AndroidResource(
                name: 'ic_launcher',
                defType: 'mipmap',
              ),
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 3,
          );
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
          (position) => _publish(position),
          onError: (Object error) {
            debugPrint('Driver location stream failed: $error');
          },
        );
  }

  Future<void> setCurrentRide(String? rideId) async {
    _currentRideId = rideId;
    final location = currentLocation.value;
    final uid = _trackingUid;
    if (location == null || uid == null) return;
    await _repository.updateDriverLocation(
      uid: uid,
      lat: location.lat,
      lng: location.lng,
      heading: location.heading,
      speed: location.speed,
      accuracy: location.accuracy,
      isOnline: true,
      currentRideId: rideId,
      vehicleType: _vehicleType,
    );
  }

  Future<void> stopDriverTracking({String? uid}) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    final driverId = uid ?? _trackingUid;
    _trackingUid = null;
    _currentRideId = null;
    _vehicleType = null;
    if (driverId != null) await _repository.setDriverOffline(driverId);
    final location = currentLocation.value;
    if (location != null) {
      currentLocation.value = LiveLocation(
        ownerId: location.ownerId,
        lat: location.lat,
        lng: location.lng,
        heading: location.heading,
        speed: location.speed,
        accuracy: location.accuracy,
        isOnline: false,
        updatedAt: DateTime.now(),
      );
    }
  }

  Stream<LiveLocation?> watchRiderLocation({
    required String riderId,
    required String rideId,
  }) {
    return _repository.watchRiderLocation(riderId: riderId, rideId: rideId);
  }

  Future<void> openLocationSettings() => Geolocator.openAppSettings();

  Future<void> _publish(Position position) async {
    final uid = _trackingUid;
    if (uid == null) return;
    final location = _fromPosition(position, isOnline: true);
    // Always updated so the driver's own in-app map/dashboard stays responsive even when the
    // backend write below is throttled.
    currentLocation.value = location;

    final now = DateTime.now();
    if (_lastPersistedAt != null &&
        now.difference(_lastPersistedAt!) < _minPersistInterval) {
      return;
    }
    _lastPersistedAt = now;

    await _repository.updateDriverLocation(
      uid: uid,
      lat: location.lat,
      lng: location.lng,
      heading: location.heading,
      speed: location.speed,
      accuracy: location.accuracy,
      isOnline: true,
      currentRideId: _currentRideId,
      vehicleType: _vehicleType,
    );
    final rideId = _currentRideId;
    if (rideId != null) await _publishRideLocation(rideId, location);
  }

  /// Phase 6B (master prompt section 14): the `driver_live_locations/{driverId}` doc this
  /// class also writes above is readable by ANY signed-in user (see firestore.rules -
  /// intentional, for the "nearby available drivers" browse-the-map feature) - it is not scoped
  /// to a specific ride, so it must never be the only source a Rider's active-ride tracking
  /// screen reads from. This additionally publishes to node-api's ride-scoped
  /// `ride_tracking/{rideId}` (PATCH /tracking/rides/:rideId/location, only readable by that
  /// ride's own rider/driver/admin - see firestore.rules' `match /ride_tracking/{rideId}`),
  /// which therian's DriverTrackingRepository.watchRideTracking now reads from for the
  /// active-ride case instead of the unrestricted collection above. Best-effort: a tracking
  /// publish failure must never interrupt the driver's own GPS stream or trip.
  Future<void> _publishRideLocation(
    String rideId,
    LiveLocation location,
  ) async {
    try {
      await ApiClient.instance.patch(
        '/api/tracking/rides/$rideId/location',
        body: {
          'location': {
            'lat': location.lat,
            'lng': location.lng,
            'heading': location.heading,
            'speed': location.speed,
            'accuracy': location.accuracy,
          },
        },
      );
    } catch (error) {
      debugPrint('[ride-location-publish-failed] rideId=$rideId error=$error');
    }
  }

  LiveLocation _fromPosition(Position position, {required bool isOnline}) {
    return LiveLocation(
      ownerId: _trackingUid ?? '',
      lat: position.latitude,
      lng: position.longitude,
      heading: position.heading,
      speed: position.speed,
      accuracy: position.accuracy,
      isOnline: isOnline,
      currentRideId: _currentRideId,
      updatedAt: DateTime.now(),
    );
  }
}
