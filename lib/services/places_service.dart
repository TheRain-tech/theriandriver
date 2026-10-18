import 'package:cloud_functions/cloud_functions.dart';

import '../config/firebase_config.dart';

/// Google Places search through the same functions-rider-maps callables the rider app's
/// "Where are you going?" screen uses (therian lib/data/services/places_service.dart):
/// searchPlaces / getPlaceDetails / reverseGeocode in africa-south1. They only require a
/// signed-in Firebase user, so a driver can call them too, and the Maps key stays server-side.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;

  factory PlaceSuggestion.fromMap(Map<String, dynamic> map) => PlaceSuggestion(
    placeId: map['placeId']?.toString() ?? '',
    primaryText: map['primaryText']?.toString() ?? '',
    secondaryText: map['secondaryText']?.toString() ?? '',
  );

  String get displayText =>
      secondaryText.isEmpty ? primaryText : '$primaryText, $secondaryText';
}

class PlaceDetails {
  const PlaceDetails({
    required this.placeId,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String placeId;
  final String address;
  final double latitude;
  final double longitude;
}

class PlacesService {
  PlacesService({FirebaseFunctions? functions})
    : _functions =
          functions ??
          FirebaseFunctions.instanceFor(region: FirebaseConfig.functionsRegion);

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final response = await _functions.httpsCallable(name).call<dynamic>(data);
    final value = response.data;
    if (value is Map) return value.cast<String, dynamic>();
    throw StateError('The map service returned no data.');
  }

  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    required String sessionToken,
    double? latitude,
    double? longitude,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    final response = await _call('searchPlaces', {
      'query': trimmed,
      'sessionToken': sessionToken,
      'latitude': latitude,
      'longitude': longitude,
    });
    return (response['suggestions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => PlaceSuggestion.fromMap(item.cast<String, dynamic>()))
        .where((item) => item.placeId.isNotEmpty)
        .toList();
  }

  Future<PlaceDetails> getDetails({
    required String placeId,
    required String sessionToken,
  }) async {
    final response = await _call('getPlaceDetails', {
      'placeId': placeId,
      'sessionToken': sessionToken,
    });
    return PlaceDetails(
      placeId: placeId,
      address: response['address']?.toString() ?? '',
      latitude: (response['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (response['longitude'] as num?)?.toDouble() ?? 0,
    );
  }

  /// The most human-readable address at a point (the callable prefers a named place or
  /// neighbourhood over a bare Plus Code - see functions-rider-maps#reverseGeocode).
  Future<String> reverseGeocode(double latitude, double longitude) async {
    final response = await _call('reverseGeocode', {
      'latitude': latitude,
      'longitude': longitude,
    });
    return response['address']?.toString() ?? '';
  }
}
