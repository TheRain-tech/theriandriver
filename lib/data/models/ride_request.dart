import 'package:cloud_firestore/cloud_firestore.dart';

import '../../firebase/firestore_collections.dart';

class RideLocation {
  const RideLocation({
    required this.lat,
    required this.lng,
    required this.address,
  });

  final double lat;
  final double lng;
  final String address;

  factory RideLocation.fromMap(Map<String, dynamic>? map) => RideLocation(
    lat:
        (map?['lat'] as num?)?.toDouble() ??
        (map?['latitude'] as num?)?.toDouble() ??
        0,
    lng:
        (map?['lng'] as num?)?.toDouble() ??
        (map?['longitude'] as num?)?.toDouble() ??
        0,
    address: map?['address']?.toString() ?? '',
  );

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng, 'address': address};
}

class RideRequest {
  const RideRequest({
    required this.requestId,
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.distanceKm,
    required this.estimatedDurationMinutes,
    required this.routePolyline,
    required this.selectedRideType,
    required this.estimatedFare,
    required this.currency,
    required this.paymentMethod,
    required this.status,
    this.assignedDriverId,
    this.assignedRideId,
    this.cancelledBy,
    this.cancellationReason,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
  });

  final String requestId;
  final String riderId;
  final String riderName;
  final String riderPhone;
  final RideLocation pickupLocation;
  final RideLocation destinationLocation;
  final double distanceKm;
  final int estimatedDurationMinutes;
  final String routePolyline;
  final String selectedRideType;
  final double estimatedFare;
  final String currency;
  final String paymentMethod;
  final String status;
  final String? assignedDriverId;
  final String? assignedRideId;
  final String? cancelledBy;
  final String? cancellationReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory RideRequest.fromMap(Map<String, dynamic> map, String id) {
    final rawStatus = map['status']?.toString() ?? RideStatuses.requested;
    return RideRequest(
      requestId: map['requestId']?.toString() ?? id,
      riderId: map['riderId']?.toString() ?? '',
      riderName: map['riderName']?.toString() ?? '',
      riderPhone: map['riderPhone']?.toString() ?? '',
      pickupLocation: RideLocation.fromMap(
        (map['pickupLocation'] as Map?)?.cast<String, dynamic>(),
      ),
      destinationLocation: RideLocation.fromMap(
        (map['destinationLocation'] as Map?)?.cast<String, dynamic>(),
      ),
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0,
      estimatedDurationMinutes:
          (map['estimatedDurationMinutes'] as num?)?.toInt() ?? 0,
      routePolyline: map['routePolyline']?.toString() ?? '',
      selectedRideType: map['selectedRideType']?.toString() ?? 'classic',
      estimatedFare: (map['estimatedFare'] as num?)?.toDouble() ?? 0,
      currency: map['currency']?.toString() ?? 'XAF',
      paymentMethod: map['paymentMethod']?.toString() ?? 'cash',
      status: RideStatuses.all.contains(rawStatus)
          ? rawStatus
          : RideStatuses.requested,
      assignedDriverId: _optional(map['assignedDriverId']),
      assignedRideId: _optional(map['assignedRideId']),
      cancelledBy: _optional(map['cancelledBy']),
      cancellationReason: _optional(map['cancellationReason']),
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      expiresAt: _date(map['expiresAt']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String? _optional(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
