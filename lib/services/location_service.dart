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

    final initial = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    await _publish(initial);

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
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
    currentLocation.value = location;
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
  Future<void> _publishRideLocation(String rideId, LiveLocation location) async {
    try {
      await ApiClient.instance.patch(
        '/tracking/rides/$rideId/location',
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
