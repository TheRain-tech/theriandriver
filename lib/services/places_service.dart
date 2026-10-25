import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_config.dart';

class PlacesServiceException implements Exception {
  const PlacesServiceException(this.message, {this.code});

  final String message;

  /// The callable's error code (e.g. 'unauthenticated', 'unavailable'), when there is one.
  final String? code;

  @override
  String toString() => code == null ? message : '$message ($code)';
}

/// Google Places search through the same functions-rider-maps callables the rider app's
/// "Where are you going?" screen uses (therian lib/data/services/places_service.dart):
/// searchPlaces / getPlaceDetails / reverseGeocode in africa-south1. They only require a
/// signed-in Firebase user, so a driver can call them too, and the Maps key stays server-side.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    this.latitude,
    this.longitude,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;

  /// Set only on a suggestion that already knows where it is (the node-api geocoder fallback) -
  /// a Places suggestion needs a getDetails call for its coordinates.
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

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

  // Same logging as the rider app's MapsService.call ([maps-callable-*]) so a failure shows the
  // callable's own code and message in the console instead of a generic error.
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    debugPrint(
      '[maps-callable-start] fn=$name region=${FirebaseConfig.functionsRegion}',
    );
    try {
      final response = await _functions.httpsCallable(name).call<dynamic>(data);
      final value = response.data;
      if (value is Map) {
        debugPrint('[maps-callable-success] fn=$name');
        return value.cast<String, dynamic>();
      }
      throw const PlacesServiceException('The map service returned no data.');
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        '[maps-callable-fail] fn=$name code=${error.code} msg=${error.message} details=${error.details}',
      );
      throw PlacesServiceException(
        error.message ?? 'The map service is unavailable. Please try again.',
        code: error.code,
      );
    }
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
