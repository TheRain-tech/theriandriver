import 'package:flutter/foundation.dart';

import 'location_service.dart';
import 'api_client.dart';

enum RoadAlertType { policeSpeedControl, traffic, roadHazard, roadWorks }

extension RoadAlertTypeApiValue on RoadAlertType {
  String get apiValue => switch (this) {
    RoadAlertType.policeSpeedControl => 'POLICE_SPEED_CONTROL',
    RoadAlertType.traffic => 'TRAFFIC',
    RoadAlertType.roadHazard => 'ROAD_HAZARD',
    RoadAlertType.roadWorks => 'ROAD_WORKS',
  };
}

/// Reports a road-safety condition (police/speed control, traffic, hazard, road works) at the
/// driver's real current GPS position - never a fabricated or client-chosen location. The
/// backend finds every other online driver in the same region and notifies them for real through
/// node-api's existing notification/FCM infrastructure; this is a thin POST, no local fan-out
/// logic lives here.
class RoadAlertService {
  RoadAlertService._();

  /// Best-effort reverse geocode of the driver's current GPS fix into a human-readable place
  /// name (e.g. "Mile 3, Limbe") so the alert reads as a real location, not just coordinates.
  /// Never allowed to block or fail the alert itself - a driver reporting police ahead must not
  /// be stuck waiting on, or blocked by, a slow/failed reverse-geocode call.
  static Future<String?> _reverseGeocodedLocationName(
    double lat,
    double lng,
  ) async {
    try {
      final response = await ApiClient.instance.get(
        '/api/maps/reverse-geocode',
        query: {'lat': lat, 'lng': lng},
      );
      final results = response is List ? response : const [];
      if (results.isEmpty) return null;
      final first = results.first;
      if (first is! Map) return null;
      final address = first['formattedAddress']?.toString().trim();
      return (address == null || address.isEmpty) ? null : address;
    } catch (error) {
      debugPrint('[road-alert] reverse geocode failed: $error');
      return null;
    }
  }

  static Future<void> report(RoadAlertType type) async {
    final location = LocationService.instance.currentLocation.value;
    if (location == null ||
        location.lat < -90 ||
        location.lat > 90 ||
        location.lng < -180 ||
        location.lng > 180 ||
        (location.lat == 0 && location.lng == 0)) {
      throw StateError(
        'Your current location is not available yet. Please try again in a moment.',
      );
    }
    final locationName = await _reverseGeocodedLocationName(
      location.lat,
      location.lng,
    );
    try {
      await ApiClient.instance.post(
        '/api/drivers/me/road-alerts',
        body: {
          'type': type.apiValue,
          'lat': location.lat,
          'lng': location.lng,
          'locationName': ?locationName,
        },
      );
    } on ApiException catch (error) {
      if (error.code == 'ROAD_ALERT_TOO_SOON') {
        throw StateError(
          'Please wait a moment before sending another road alert.',
        );
      }
      if (error.code == 'ROAD_ALERT_REGION_REQUIRED') {
        throw StateError(
          'Your driver profile has no region set yet. Please contact support.',
        );
      }
      throw StateError(error.message);
    }
  }
}
