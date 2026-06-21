import 'package:cloud_firestore/cloud_firestore.dart';

class LiveLocation {
  const LiveLocation({
    required this.ownerId,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.speed,
    required this.accuracy,
    required this.isOnline,
    this.currentRideId,
    this.updatedAt,
  });

  final String ownerId;
  final double lat;
  final double lng;
  final double heading;
  final double speed;
  final double accuracy;
  final bool isOnline;
  final String? currentRideId;
  final DateTime? updatedAt;

  factory LiveLocation.fromDriverMap(Map<String, dynamic> map, String id) =>
      LiveLocation(
        ownerId: map['driverId']?.toString() ?? id,
        lat: (map['lat'] as num?)?.toDouble() ?? 0,
        lng: (map['lng'] as num?)?.toDouble() ?? 0,
        heading: (map['heading'] as num?)?.toDouble() ?? 0,
        speed: (map['speed'] as num?)?.toDouble() ?? 0,
        accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
        isOnline: map['isOnline'] == true,
        currentRideId: _optional(map['currentRideId']),
        updatedAt: _date(map['updatedAt']),
      );

  factory LiveLocation.fromRiderMap(Map<String, dynamic> map, String id) =>
      LiveLocation(
        ownerId: map['riderId']?.toString() ?? id,
        lat:
            (map['lat'] as num?)?.toDouble() ??
            (map['latitude'] as num?)?.toDouble() ??
            0,
        lng:
            (map['lng'] as num?)?.toDouble() ??
            (map['longitude'] as num?)?.toDouble() ??
            0,
        heading: (map['heading'] as num?)?.toDouble() ?? 0,
        speed: (map['speed'] as num?)?.toDouble() ?? 0,
        accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
        isOnline: true,
        currentRideId: _optional(map['currentRideId']),
        updatedAt: _date(map['updatedAt']),
      );

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String? _optional(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
