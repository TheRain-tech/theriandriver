import '../../services/api_client.dart';
import '../models/ride_request.dart';
import '../models/street_pickup_quote.dart';

/// node-api lookups the Street Pickup sheet needs before a ride exists: turning the driver's
/// position into an address, resolving a typed destination, and quoting the fare. All three go
/// through node-api (Google Maps server-side) rather than a client-side Maps key.
class StreetPickupRepository {
  StreetPickupRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  /// The ride types the sheet offers, in the rider app's own vocabulary (stored as the ride's
  /// selectedRideType so a street pickup reads exactly like a booked ride everywhere else).
  static const rideTypes = ['classic', 'comfort', 'vip'];

  /// Same mapping the rider app uses for node-api pricing
  /// (therian rider_ride_api_client.dart#mapAppRideClassToNodeApiRideType).
  static String nodeApiRideType(String rideType) =>
      rideType == 'vip' ? 'premium' : 'standard';

  Future<String?> addressFor(double lat, double lng) async {
    try {
      final data = await _api.get(
        '/api/maps/reverse-geocode',
        query: {'lat': lat, 'lng': lng},
      );
      if (data is List && data.isNotEmpty && data.first is Map) {
        final address = (data.first as Map)['formattedAddress']?.toString();
        if (address != null && address.trim().isNotEmpty) return address;
      }
    } catch (_) {
      // The caller falls back to showing the coordinates as "current location".
    }
    return null;
  }

  Future<List<RideLocation>> searchDestination(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];
    final data = await _api.get(
      '/api/maps/geocode',
      query: {'address': trimmed},
    );
    if (data is! List) return const [];
    return [
      for (final item in data.whereType<Map>())
        if (item['location'] is Map &&
            (item['location'] as Map)['lat'] is num &&
            (item['location'] as Map)['lng'] is num)
          RideLocation(
            lat: ((item['location'] as Map)['lat'] as num).toDouble(),
            lng: ((item['location'] as Map)['lng'] as num).toDouble(),
            address: item['formattedAddress']?.toString() ?? trimmed,
          ),
    ].take(5).toList(growable: false);
  }

  Future<StreetPickupQuote> quote({
    required RideLocation pickup,
    required RideLocation destination,
    required String rideType,
    String? regionId,
  }) async {
    final data = await _api.post(
      '/api/rides/estimate',
      body: {
        'pickup': pickup.toMap(),
        'destination': destination.toMap(),
        'rideType': nodeApiRideType(rideType),
        if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
      },
    );
    if (data is! Map) throw StateError('Could not estimate the fare.');
    return StreetPickupQuote.fromApi(data.cast<String, dynamic>());
  }
}
