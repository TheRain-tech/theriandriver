import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../config/env_config.dart';
import '../../config/firebase_config.dart';
import '../../firebase/firestore_collections.dart';
import '../../services/api_client.dart';
import '../mock/mock_driver_trips.dart';
import '../models/app_enums.dart';
import '../models/driver_trip.dart';
import '../models/ride_request.dart';

class RideRepository {
  RideRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestoreOverride = firestore,
      _functionsOverride = functions;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: FirebaseConfig.functionsRegion);

  bool get _usePreview =>
      EnvConfig.previewMode || FirebaseConfig.useMockFallback;

  Stream<RideRequest?> watchIncomingRequest(String uid) {
    if (_usePreview) return Stream.value(_mockRequest(uid));
    if (!FirebaseConfig.isAvailable) return Stream.value(null);

    return _db
        .collection(FirestoreCollections.rideRequests)
        .where('assignedDriverId', isEqualTo: uid)
        .where(
          'status',
          whereIn: [
            RideStatuses.searching,
            RideStatuses.requestedSpecificDriver,
          ],
        )
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final document = snapshot.docs.first;
          final request = RideRequest.fromMap(document.data(), document.id);
          return request.isExpired ? null : request;
        });
  }

  Stream<DriverTrip?> watchRide(String rideId) {
    if (_usePreview) return Stream.value(mockDriverTrips.first);
    if (!FirebaseConfig.isAvailable) return Stream.value(null);
    return _db
        .collection(FirestoreCollections.rides)
        .doc(rideId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return data == null ? null : DriverTrip.fromMap(data, snapshot.id);
        });
  }

  Stream<List<DriverTrip>> watchDriverTrips(String uid) {
    if (_usePreview) return Stream.value(List.unmodifiable(mockDriverTrips));
    if (!FirebaseConfig.isAvailable) return Stream.value(const []);
    return _db
        .collection(FirestoreCollections.rides)
        .where('driverId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DriverTrip.fromMap(doc.data(), doc.id))
              .toList(growable: false),
        );
  }

  Future<DriverTrip?> getRide(String rideId) async {
    if (_usePreview) return mockDriverTrips.firstOrNull;
    if (!FirebaseConfig.isAvailable) return null;
    final snapshot = await _db
        .collection(FirestoreCollections.rides)
        .doc(rideId)
        .get();
    final data = snapshot.data();
    return data == null ? null : DriverTrip.fromMap(data, snapshot.id);
  }

  Future<DriverTrip> acceptRideRequest({
    required String uid,
    required RideRequest request,
    String? vehicleId,
  }) async {
    if (_usePreview) return _tripFromRequest(uid, request);
    if (!FirebaseConfig.isAvailable) {
      throw StateError('Firebase is unavailable.');
    }

    // Ride acceptance updates protected records and has to be atomic. The
    // callable verifies that this signed-in driver still owns the live offer,
    // then creates the ride and marks the driver busy server-side.
    final response = await _functions
        .httpsCallable('acceptRiderRideRequest')
        .call<Map<Object?, Object?>>({
          'requestId': request.requestId,
          if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
        });
    final responseData = response.data;
    final rideId = responseData['rideId']?.toString();
    if (rideId == null || rideId.isEmpty) {
      throw StateError('The accepted ride could not be loaded.');
    }
    final rideSnapshot = await _db
        .collection(FirestoreCollections.rides)
        .doc(rideId)
        .get();
    final rideData = rideSnapshot.data();
    if (rideData == null) {
      throw StateError('The accepted ride could not be loaded.');
    }
    return DriverTrip.fromMap(rideData, rideSnapshot.id);
  }

  Future<void> declineRideRequest({
    required String uid,
    required String requestId,
  }) async {
    if (_usePreview) return;
    if (!FirebaseConfig.isAvailable) {
      throw StateError('Firebase is unavailable.');
    }

    final requestRef = _db
        .collection(FirestoreCollections.rideRequests)
        .doc(requestId);
    final activityRef = _db
        .collection(FirestoreCollections.driverActivityLogs)
        .doc();
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(requestRef);
      final data = snapshot.data();
      if (data == null) return;

      if ((data['status'] != RideStatuses.searching &&
              data['status'] != RideStatuses.requestedSpecificDriver) ||
          data['assignedDriverId'] != uid) {
        return;
      }
      final nextStatus = data['status'] == RideStatuses.requestedSpecificDriver
          ? RideStatuses.driverRejected
          : RideStatuses.searching;
      transaction.update(requestRef, {
        'status': nextStatus,
        'assignedDriverId': null,
        'lastRejectedDriverId': uid,
        'rejectedDriverIds': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(activityRef, {
        'logId': activityRef.id,
        'driverId': uid,
        'type': 'rideRequestDeclined',
        'rideRequestId': requestId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Phase 6B: the ride-lifecycle status transition itself is delegated to node-api's
  /// transactional, rules-consistent `PATCH /rides/:rideId/status` / `POST /rides/:rideId/start`
  /// / `POST /rides/:rideId/cancel` endpoints (services/ride.service.js#setStatus et al.) instead
  /// of a direct client Firestore transaction - see docs/platform/phase-6b/
  /// DRIVER_NODE_API_MIGRATION.md for why the ride-offer/acceptance layer above this is NOT
  /// migrated in this same pass. node-api's RIDE_STATUS enum values are, deliberately or not,
  /// already the same lowercase-underscore strings as this app's own RideStatuses (confirmed by
  /// reading therainAdmin/node-api/utils/constants.js) with one exception - it writes the bare
  /// 'cancelled' rather than 'cancelled_by_driver'/'cancelled_by_rider' - handled in
  /// DriverTrip._tripStatus.
  ///
  /// node-api does not know about this app's separate `ride_requests` staging collection or the
  /// driver doc's own currentRideId/currentRideStatus/status mirror fields, so those are kept in
  /// sync here with a small best-effort follow-up write rather than folding them into node-api's
  /// canonical model in this pass.
  Future<void> transitionRide({
    required String uid,
    required String rideId,
    required String requestId,
    required String nextStatus,
    String? reason,
  }) async {
    if (_usePreview) return;
    if (!FirebaseConfig.isAvailable) {
      throw StateError('Firebase is unavailable.');
    }
    final isCancel =
        nextStatus == RideStatuses.cancelled ||
        nextStatus == RideStatuses.cancelledByRider ||
        nextStatus == RideStatuses.cancelledByDriver;
    if (!isCancel &&
        nextStatus != RideStatuses.driverArriving &&
        nextStatus != RideStatuses.arrived &&
        nextStatus != RideStatuses.ongoing) {
      throw StateError('Unsupported ride transition: $nextStatus');
    }

    try {
      if (isCancel) {
        await ApiClient.instance.post(
          '/api/rides/$rideId/cancel',
          body: {'reason': reason},
        );
      } else if (nextStatus == RideStatuses.ongoing) {
        await ApiClient.instance.post('/api/rides/$rideId/start');
      } else {
        // driverArriving -> node-api's DRIVER_ARRIVING; arrived -> node-api's AT_PICKUP. Both
        // map onto the one generic status-transition endpoint (setStatus validates the
        // from/to transition server-side via assertStatusTransition - the allowedPrevious set
        // this method used to check client-side is now enforced there instead).
        final canonicalStatus = nextStatus == RideStatuses.driverArriving
            ? 'DRIVER_ARRIVING'
            : 'AT_PICKUP';
        await ApiClient.instance.patch(
          '/api/rides/$rideId/status',
          body: {'status': canonicalStatus},
        );
      }
    } on ApiException catch (error) {
      if (error.isConflict) {
        throw StateError('The ride status changed. Refresh and try again.');
      }
      if (error.isNotFound) {
        throw StateError('The active ride was not found.');
      }
      rethrow;
    }

    final requestRef = _db
        .collection(FirestoreCollections.rideRequests)
        .doc(requestId);
    final driverRef = _db.collection(FirestoreCollections.drivers).doc(uid);
    await _db.runTransaction((transaction) async {
      transaction.set(requestRef, {
        'status': nextStatus,
        // ignore: use_null_aware_elements
        if (reason != null) 'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(driverRef, {
        'currentRideStatus': nextStatus,
        if (isCancel) ...{'currentRideId': null, 'status': 'online'},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Phase 6B: delegates to node-api's `POST /rides/:rideId/complete` (which itself handles the
  /// receipt, commission deduction, and driver payout credit - see
  /// services/ride.service.js#completeRide) instead of the `completeRideAndSettleEarnings` Cloud
  /// Function. See this class's transitionRide doc comment for why the driver doc's own
  /// currentRideId/status mirror fields are still updated here directly.
  Future<void> completeRide({
    required String uid,
    required DriverTrip trip,
  }) async {
    if (_usePreview) return;
    if (!FirebaseConfig.isAvailable) {
      throw StateError('Firebase is unavailable.');
    }

    try {
      await ApiClient.instance.post('/api/rides/${trip.id}/complete');
    } on ApiException catch (error) {
      if (error.isNotFound) {
        throw StateError('The active ride was not found.');
      }
      rethrow;
    }

    await _db.collection(FirestoreCollections.drivers).doc(uid).set({
      'currentRideId': null,
      'currentRideStatus': RideStatuses.completed,
      'status': 'online',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Records the driver's rating of the rider for a completed trip. Written under
  /// `driverRatingOfRider`/`driverRatedRiderAt` - deliberately distinct from the existing
  /// `riderRating` field on the ride/DriverTrip model, which holds the rider's own aggregate
  /// rating (shown to the driver before accepting), not a slot for this one-trip score.
  Future<void> submitRiderRating({
    required String uid,
    required String rideId,
    required int rating,
  }) async {
    if (_usePreview) return;
    if (!FirebaseConfig.isAvailable) {
      throw StateError('Firebase is unavailable.');
    }
    final rideRef = _db.collection(FirestoreCollections.rides).doc(rideId);
    final snapshot = await rideRef.get();
    final data = snapshot.data();
    if (data == null || data['driverId'] != uid) {
      throw StateError('The trip was not found.');
    }
    await rideRef.update({
      'driverRatingOfRider': rating,
      'driverRatedRiderAt': FieldValue.serverTimestamp(),
    });
  }

  RideRequest _mockRequest(String uid) {
    final trip = mockDriverTrips.first;
    return RideRequest(
      requestId: 'preview-request',
      riderId: 'preview-rider',
      riderName: trip.riderName,
      riderPhone: '',
      pickupLocation: RideLocation(
        lat: 5.9631,
        lng: 10.1591,
        address: trip.pickup,
      ),
      destinationLocation: RideLocation(
        lat: 5.9762,
        lng: 10.1814,
        address: trip.dropOff,
      ),
      distanceKm: trip.distanceKm,
      estimatedDurationMinutes: trip.durationMinutes,
      routePolyline: '',
      selectedRideType: trip.rideType.toLowerCase(),
      estimatedFare: trip.fare,
      currency: 'XAF',
      paymentMethod: 'cash',
      status: RideStatuses.searching,
      assignedDriverId: uid,
      expiresAt: DateTime.now().add(const Duration(minutes: 2)),
    );
  }

  DriverTrip _tripFromRequest(
    String uid,
    RideRequest request, {
    String? rideId,
  }) {
    return DriverTrip(
      id: rideId ?? 'preview-ride',
      driverId: uid,
      riderName: request.riderName,
      riderRating: 0,
      pickup: request.pickupLocation.address,
      dropOff: request.destinationLocation.address,
      fare: request.estimatedFare,
      paymentMethod: request.paymentMethod == 'mobile_money'
          ? PaymentMethod.mobileMoney
          : PaymentMethod.cash,
      paymentStatus: PaymentStatus.pending,
      status: TripStatus.accepted,
      rideType: request.selectedRideType,
      distanceKm: request.distanceKm,
      durationMinutes: request.estimatedDurationMinutes,
      createdAt: DateTime.now(),
      requestId: request.requestId,
      riderId: request.riderId,
      riderPhone: request.riderPhone,
      pickupLat: request.pickupLocation.lat,
      pickupLng: request.pickupLocation.lng,
      dropOffLat: request.destinationLocation.lat,
      dropOffLng: request.destinationLocation.lng,
      routePolyline: request.routePolyline,
    );
  }
}
