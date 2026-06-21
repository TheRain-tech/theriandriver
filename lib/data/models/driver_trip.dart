import 'package:cloud_firestore/cloud_firestore.dart';

import '../../firebase/firestore_collections.dart';
import 'app_enums.dart';
import 'ride_request.dart';

class DriverTrip {
  const DriverTrip({
    required this.id,
    required this.driverId,
    required this.riderName,
    required this.riderRating,
    required this.pickup,
    required this.dropOff,
    required this.fare,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.rideType,
    required this.distanceKm,
    required this.durationMinutes,
    required this.createdAt,
    this.note,
    this.requestId = '',
    this.riderId = '',
    this.riderPhone = '',
    this.pickupLat = 0,
    this.pickupLng = 0,
    this.dropOffLat = 0,
    this.dropOffLng = 0,
    this.routePolyline = '',
    this.pickupCode = '',
  });

  final String id;
  final String driverId;
  final String riderName;
  final double riderRating;
  final String pickup;
  final String dropOff;
  final double fare;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final TripStatus status;
  final String rideType;
  final double distanceKm;
  final int durationMinutes;
  final DateTime createdAt;
  final String? note;
  final String requestId;
  final String riderId;
  final String riderPhone;
  final double pickupLat;
  final double pickupLng;
  final double dropOffLat;
  final double dropOffLng;
  final String routePolyline;
  final String pickupCode;

  DriverTrip copyWith({
    TripStatus? status,
    PaymentStatus? paymentStatus,
    double? fare,
  }) {
    return DriverTrip(
      id: id,
      driverId: driverId,
      riderName: riderName,
      riderRating: riderRating,
      pickup: pickup,
      dropOff: dropOff,
      fare: fare ?? this.fare,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      rideType: rideType,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      createdAt: createdAt,
      note: note,
      requestId: requestId,
      riderId: riderId,
      riderPhone: riderPhone,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropOffLat: dropOffLat,
      dropOffLng: dropOffLng,
      routePolyline: routePolyline,
      pickupCode: pickupCode,
    );
  }

  factory DriverTrip.fromJson(Map<String, dynamic> json) =>
      DriverTrip.fromMap(json, json['id']?.toString() ?? '');

  factory DriverTrip.fromMap(Map<String, dynamic> map, String id) {
    final pickup = RideLocation.fromMap(
      (map['pickupLocation'] as Map?)?.cast<String, dynamic>(),
    );
    final destination = RideLocation.fromMap(
      (map['destinationLocation'] as Map?)?.cast<String, dynamic>(),
    );
    final status = map['status']?.toString() ?? RideStatuses.requested;

    return DriverTrip(
      id: map['rideId']?.toString() ?? id,
      driverId: map['driverId']?.toString() ?? '',
      riderName: map['riderName']?.toString() ?? 'Rider',
      riderRating: (map['riderRating'] as num?)?.toDouble() ?? 0,
      pickup: pickup.address.isNotEmpty
          ? pickup.address
          : map['pickup']?.toString() ?? '',
      dropOff: destination.address.isNotEmpty
          ? destination.address
          : map['dropOff']?.toString() ?? '',
      fare:
          (map['finalFare'] as num?)?.toDouble() ??
          (map['estimatedFare'] as num?)?.toDouble() ??
          (map['fare'] as num?)?.toDouble() ??
          0,
      paymentMethod: enumByName(
        PaymentMethod.values,
        _camelPaymentMethod(map['paymentMethod']),
        PaymentMethod.cash,
      ),
      paymentStatus: enumByName(
        PaymentStatus.values,
        map['paymentStatus'],
        PaymentStatus.pending,
      ),
      status: _tripStatus(status),
      rideType:
          map['selectedRideType']?.toString() ??
          map['rideType']?.toString() ??
          'classic',
      distanceKm:
          (map['distanceKm'] as num?)?.toDouble() ??
          (map['distance'] as num?)?.toDouble() ??
          0,
      durationMinutes:
          (map['estimatedDurationMinutes'] as num?)?.toInt() ??
          (map['durationMinutes'] as num?)?.toInt() ??
          0,
      createdAt: _date(map['createdAt']) ?? DateTime.now(),
      note: map['note']?.toString(),
      requestId:
          map['requestId']?.toString() ??
          map['rideRequestId']?.toString() ??
          '',
      riderId: map['riderId']?.toString() ?? '',
      riderPhone: map['riderPhone']?.toString() ?? '',
      pickupLat: pickup.lat,
      pickupLng: pickup.lng,
      dropOffLat: destination.lat,
      dropOffLng: destination.lng,
      routePolyline: map['routePolyline']?.toString() ?? '',
      pickupCode: map['pickupCode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'driverId': driverId,
    'riderName': riderName,
    'riderRating': riderRating,
    'pickup': pickup,
    'dropOff': dropOff,
    'fare': fare,
    'paymentMethod': paymentMethod.name,
    'paymentStatus': paymentStatus.name,
    'status': status.name,
    'rideType': rideType,
    'distanceKm': distanceKm,
    'durationMinutes': durationMinutes,
    'createdAt': createdAt.toIso8601String(),
    'note': note,
  };

  static TripStatus _tripStatus(String status) => switch (status) {
    RideStatuses.accepted => TripStatus.accepted,
    RideStatuses.driverArriving => TripStatus.goingToPickup,
    RideStatuses.arrived => TripStatus.arrived,
    RideStatuses.ongoing => TripStatus.inProgress,
    RideStatuses.completed => TripStatus.completed,
    RideStatuses.cancelled => TripStatus.cancelled,
    RideStatuses.expired => TripStatus.missed,
    _ => TripStatus.requested,
  };

  static Object? _camelPaymentMethod(Object? value) {
    return value?.toString() == 'mobile_money' ? 'mobileMoney' : value;
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
