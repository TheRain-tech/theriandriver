import 'package:flutter/foundation.dart';

import '../data/models/driver_trip.dart';
import '../data/models/ride_request.dart';

class TripService {
  TripService._();
  static final instance = TripService._();

  final ValueNotifier<DriverTrip?> activeTrip = ValueNotifier(null);
  final ValueNotifier<RideRequest?> incomingRequest = ValueNotifier(null);
  // "Queue the next ride": a ride accepted while already in_progress on activeTrip (see
  // ride_repository.dart#acceptRideRequest) is held here, not in activeTrip, until the current
  // trip ends - promoted to activeTrip by trip_completed_screen.dart (normal completion) or by
  // the relevant trip screen's own cancellation handler (rider cancels the current trip while
  // one is already queued).
  final ValueNotifier<DriverTrip?> queuedTrip = ValueNotifier(null);

  void clearActiveTrip() => activeTrip.value = null;
  void clearIncomingRequest() => incomingRequest.value = null;
}
