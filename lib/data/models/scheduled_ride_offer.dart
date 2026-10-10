/// A scheduled_rides doc (node-api/services/scheduledRide.service.js) a driver can pre-accept
/// ahead of its activation window - mirrors just the fields GET /api/rides/scheduled/nearby
/// returns, not the full rider-side booking shape.
class ScheduledRideOffer {
  const ScheduledRideOffer({
    required this.id,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.scheduledPickupAt,
    required this.rideType,
    required this.fareAmount,
    required this.currency,
  });

  final String id;
  final String pickupAddress;
  final String destinationAddress;
  final DateTime scheduledPickupAt;
  final String rideType;
  final num fareAmount;
  final String currency;

  factory ScheduledRideOffer.fromMap(Map<String, dynamic> map) {
    final pricing = map['pricing'] is Map
        ? Map<String, dynamic>.from(map['pricing'] as Map)
        : const <String, dynamic>{};
    final pickup = map['pickup'] is Map
        ? Map<String, dynamic>.from(map['pickup'] as Map)
        : const <String, dynamic>{};
    final destination = map['destination'] is Map
        ? Map<String, dynamic>.from(map['destination'] as Map)
        : const <String, dynamic>{};
    return ScheduledRideOffer(
      id: map['id']?.toString() ?? '',
      pickupAddress: pickup['address']?.toString() ?? '',
      destinationAddress: destination['address']?.toString() ?? '',
      scheduledPickupAt:
          DateTime.tryParse(map['scheduledPickupAt']?.toString() ?? '') ??
          DateTime.now(),
      rideType: map['rideType']?.toString() ?? 'standard',
      fareAmount:
          (pricing['estimatedFareXaf'] ?? pricing['total'] ?? 0) as num,
      currency: pricing['currency']?.toString() ?? 'XAF',
    );
  }
}
