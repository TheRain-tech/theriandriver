import 'package:flutter/foundation.dart';

import '../data/models/driver_trip.dart';
import '../data/models/ride_request.dart';

class TripService {
  TripService._();
  static final instance = TripService._();

  final ValueNotifier<DriverTrip?> activeTrip = ValueNotifier(null);
  final ValueNotifier<RideRequest?> incomingRequest = ValueNotifier(null);

  void clearActiveTrip() => activeTrip.value = null;
  void clearIncomingRequest() => incomingRequest.value = null;
}
