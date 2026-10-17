/// node-api's fare estimate (POST /api/rides/estimate) for a street pickup - the same
/// Super-Admin regional pricing and Google route a rider's own booking is quoted from, so a
/// street pickup is never priced by a separate, app-side rate table.
class StreetPickupQuote {
  const StreetPickupQuote({
    required this.fare,
    required this.currency,
    required this.distanceKm,
    required this.durationMinutes,
    this.routePolyline = '',
    this.regionId,
  });

  final double fare;
  final String currency;
  final double distanceKm;
  final int durationMinutes;
  final String routePolyline;
  final String? regionId;

  factory StreetPickupQuote.fromApi(Map<String, dynamic> data) {
    final fare =
        (data['total'] as num?) ??
        (data['estimatedFare'] as num?) ??
        (data['fare'] as num?) ??
        0;
    final distanceMeters = data['distanceMeters'] as num?;
    final distanceKm =
        (data['distanceKm'] as num?)?.toDouble() ??
        (distanceMeters == null ? 0.0 : distanceMeters / 1000);
    final durationSeconds = data['durationSeconds'] as num?;
    final durationMinutes =
        (data['durationMinutes'] as num?)?.round() ??
        (durationSeconds == null ? 0 : (durationSeconds / 60).ceil());
    return StreetPickupQuote(
      fare: fare.toDouble(),
      currency: data['currency']?.toString() ?? 'XAF',
      distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
      durationMinutes: durationMinutes,
      routePolyline: data['encodedPolyline']?.toString() ?? '',
      regionId: data['regionId']?.toString(),
    );
  }
}
