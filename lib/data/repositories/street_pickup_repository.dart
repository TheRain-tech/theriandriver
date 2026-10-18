import '../../services/api_client.dart';
import '../../services/places_service.dart';
import '../models/ride_request.dart';
import '../models/street_pickup_quote.dart';

/// Lookups the Street Pickup sheet needs before a ride exists: turning the driver's position
/// into an address, finding the destination, and quoting the fare. All of it goes through
/// TheRain's servers (node-api and the rider app's maps callables) rather than a client-side
/// Maps key.
class StreetPickupRepository {
  StreetPickupRepository({ApiClient? api, PlacesService? places})
    : _api = api ?? ApiClient.instance,
      _places = places ?? PlacesService();

  final ApiClient _api;
  final PlacesService _places;

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

  /// Destination autocomplete - the rider app's own Places search (see PlacesService), so a
  /// driver finds a place exactly the way a rider booking to it would.
  Future<List<PlaceSuggestion>> searchDestination({
    required String query,
    required String sessionToken,
    double? latitude,
    double? longitude,
  }) {
    return _places.autocomplete(
      query: query,
      sessionToken: sessionToken,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Coordinates for a chosen suggestion. Keeps the suggestion's own text as the address - the
  /// exact place name the driver saw and tapped - the same rule the rider app follows
  /// (booking_place_search_service.dart#resolve).
  Future<RideLocation> resolveDestination({
    required PlaceSuggestion suggestion,
    required String sessionToken,
  }) async {
    final details = await _places.getDetails(
      placeId: suggestion.placeId,
      sessionToken: sessionToken,
    );
    if (details.latitude == 0 && details.longitude == 0) {
      throw StateError('This place has no location.');
    }
    final address = suggestion.displayText.isNotEmpty
        ? suggestion.displayText
        : details.address;
    return RideLocation(
      lat: details.latitude,
      lng: details.longitude,
      address: address,
    );
  }

  /// Address under a map pin. Prefers the rider app's reverseGeocode callable (named places
  /// over Plus Codes), then node-api's geocoder.
  Future<String?> addressAt(double lat, double lng) async {
    try {
      final address = await _places.reverseGeocode(lat, lng);
      if (address.trim().isNotEmpty) return address;
    } catch (_) {}
    return addressFor(lat, lng);
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
