import 'location_service.dart';
import 'api_client.dart';

enum RoadAlertType { policeSpeedControl, roadHazard, roadWorks }

extension RoadAlertTypeApiValue on RoadAlertType {
  String get apiValue => switch (this) {
    RoadAlertType.policeSpeedControl => 'POLICE_SPEED_CONTROL',
    RoadAlertType.roadHazard => 'ROAD_HAZARD',
    RoadAlertType.roadWorks => 'ROAD_WORKS',
  };
}

/// Reports a road-safety condition (police/speed control, hazard, road works) at the driver's
/// real current GPS position - never a fabricated or client-chosen location. The backend finds
/// nearby online drivers and notifies them for real through node-api's existing notification/FCM
/// infrastructure; this is a thin POST, no local fan-out logic lives here.
class RoadAlertService {
  RoadAlertService._();

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
    try {
      await ApiClient.instance.post(
        '/api/drivers/me/road-alerts',
        body: {
          'type': type.apiValue,
          'lat': location.lat,
          'lng': location.lng,
        },
      );
    } on ApiException catch (error) {
      if (error.code == 'ROAD_ALERT_TOO_SOON') {
        throw StateError(
          'Please wait a moment before sending another road alert.',
        );
      }
      throw StateError(error.message);
    }
  }
}
