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
    this.scheduledPickupAt,
    this.commissionRatePercent,
    this.commissionAmount,
    this.driverEarnings,
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
  // Present only for a ride that came from node-api's scheduled-ride pipeline (see
  // node-api/services/scheduledRide.service.js) - null for every normal on-demand trip. Drives
  // PickupConfirmedScreen's "waiting until pickup" countdown instead of the plain arrived state.
  final DateTime? scheduledPickupAt;

  // Written by the server when the trip completes: the Super Admin's commission rate at that moment, the
  // commission on the fare that was booked and paid, and what is left for the driver. Null until then -
  // the app never works these out itself.
  final double? commissionRatePercent;
  final double? commissionAmount;
  final double? driverEarnings;

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
      scheduledPickupAt: scheduledPickupAt,
      commissionRatePercent: commissionRatePercent,
      commissionAmount: commissionAmount,
      driverEarnings: driverEarnings,
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
          (map['finalFareAmount'] as num?)?.toDouble() ??
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
      scheduledPickupAt: _date(map['scheduledPickupAt']),
      // Only once the server has stamped the financial snapshot: before that the acceptance-time
      // placeholder percentage on the ride is not a real commission and is never shown.
      commissionRatePercent: map['financialSnapshotAt'] == null
          ? null
          : (map['commissionRatePercent'] as num?)?.toDouble(),
      commissionAmount: map['financialSnapshotAt'] == null
          ? null
          : (map['commissionAmount'] as num?)?.toDouble(),
      driverEarnings: map['financialSnapshotAt'] == null
          ? null
          : (map['netAmount'] as num?)?.toDouble(),
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
    // node-api's ride.service.js (RIDE_STATUS.CANCELLED) writes the bare 'cancelled' - this
    // app's own direct-Firestore writes use the more specific 'cancelled_by_driver'/
    // 'cancelled_by_rider'. All three must map to the same TripStatus so a node-api-driven
    // cancellation (see RideRepository#transitionRide/cancelRide) renders correctly instead of
    // silently falling through to the `_` case below.
    RideStatuses.cancelled ||
    RideStatuses.cancelledByRider ||
    'cancelled' => TripStatus.cancelled,
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
