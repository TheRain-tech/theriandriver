import 'package:flutter/foundation.dart';

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
  ///
  /// If that callable fails for a driver (driver logins live in their own Identity Platform
  /// tenant, which functions-rider-maps was built and tested for rider logins only - see
  /// IDENTITY_AND_AUTHORIZATION_CONTRACT.md section 10), falls back to node-api's geocoder,
  /// which verifies driver-tenant tokens properly, so the driver still gets suggestions. The
  /// callable's own error is logged and rethrown only if the fallback finds nothing either.
  Future<List<PlaceSuggestion>> searchDestination({
    required String query,
    required String sessionToken,
    double? latitude,
    double? longitude,
  }) async {
    try {
      return await _places.autocomplete(
        query: query,
        sessionToken: sessionToken,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (placesError) {
      debugPrint('[street-pickup-search] places search failed: $placesError');
      try {
        final fallback = await _geocodeSuggestions(query);
        debugPrint(
          '[street-pickup-search] node-api geocoder fallback: ${fallback.length} result(s)',
        );
        if (fallback.isNotEmpty) return fallback;
      } catch (geocodeError) {
        debugPrint(
          '[street-pickup-search] node-api geocoder fallback failed: $geocodeError',
        );
      }
      rethrow;
    }
  }

  Future<List<PlaceSuggestion>> _geocodeSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];
    final data = await _api.get(
      '/api/maps/geocode',
      query: {'address': trimmed},
    );
    if (data is! List) return const [];
    final suggestions = <PlaceSuggestion>[];
    for (final item in data.whereType<Map>()) {
      final location = item['location'];
      if (location is! Map ||
          location['lat'] is! num ||
          location['lng'] is! num) {
        continue;
      }
      final address = item['formattedAddress']?.toString() ?? trimmed;
      final comma = address.indexOf(',');
      suggestions.add(
        PlaceSuggestion(
          placeId: item['placeId']?.toString() ?? '',
          primaryText: comma < 0 ? address : address.substring(0, comma),
          secondaryText: comma < 0 ? '' : address.substring(comma + 1).trim(),
          latitude: (location['lat'] as num).toDouble(),
          longitude: (location['lng'] as num).toDouble(),
        ),
      );
      if (suggestions.length == 5) break;
    }
    return suggestions;
  }

  /// Coordinates for a chosen suggestion. Keeps the suggestion's own text as the address - the
  /// exact place name the driver saw and tapped - the same rule the rider app follows
  /// (booking_place_search_service.dart#resolve).
  Future<RideLocation> resolveDestination({
    required PlaceSuggestion suggestion,
    required String sessionToken,
  }) async {
    if (suggestion.hasCoordinates) {
      return RideLocation(
        lat: suggestion.latitude!,
        lng: suggestion.longitude!,
        address: suggestion.displayText,
      );
    }
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

  // A Google Plus Code ("X552+V8H", "252M+5V Bamenda") - what reverse geocoding returns first
  // across much of Cameroon, where street-level address data is sparse.
  static final _plusCode = RegExp(
    r'^[23456789CFGHJMPQRVWX]{2,8}\+[23456789CFGHJMPQRVWX]*[\s,]*',
    caseSensitive: false,
  );

  static bool isPlusCode(String address) => _plusCode.hasMatch(address.trim());

  /// "X552+V8H, Douala, Cameroon" -> "Douala, Cameroon".
  static String withoutPlusCode(String address) =>
      address.trim().replaceFirst(_plusCode, '').trim();

  // Same preference order functions-rider-maps#reverseGeocode uses: a named place right at the
  // point, else the neighbourhood / district / town containing it.
  static const _readableTypes = [
    'point_of_interest',
    'establishment',
    'premise',
    'route',
    'neighborhood',
    'sublocality_level_1',
    'sublocality',
    'locality',
  ];

  /// A place name a passenger will recognise for these coordinates - never a bare Plus Code.
  /// Used for the trip details shared with a street pickup passenger.
  Future<String?> readableAddressAt(double lat, double lng) async {
    try {
      final address = await _places.reverseGeocode(lat, lng);
      if (address.trim().isNotEmpty && !isPlusCode(address)) return address;
    } catch (_) {}
    try {
      final data = await _api.get(
        '/api/maps/reverse-geocode',
        query: {'lat': lat, 'lng': lng},
      );
      if (data is List) {
        final results = data.whereType<Map>().toList();
        String addressOf(Map result) =>
            result['formattedAddress']?.toString().trim() ?? '';
        List<String> typesOf(Map result) => (result['types'] is List)
            ? (result['types'] as List).map((type) => '$type').toList()
            : const [];
        final readable = results
            .where(
              (result) =>
                  addressOf(result).isNotEmpty &&
                  !isPlusCode(addressOf(result)) &&
                  !typesOf(result).contains('plus_code'),
            )
            .toList();
        for (final type in _readableTypes) {
          for (final result in readable) {
            if (typesOf(result).contains(type)) return addressOf(result);
          }
        }
        if (readable.isNotEmpty) return addressOf(readable.first);
        for (final result in results) {
          final stripped = withoutPlusCode(addressOf(result));
          if (stripped.isNotEmpty) return stripped;
        }
      }
    } catch (_) {}
    return null;
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
