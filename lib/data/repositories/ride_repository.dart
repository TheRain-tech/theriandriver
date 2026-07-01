import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../config/env_config.dart';
import '../../config/firebase_config.dart';
import '../../firebase/firestore_collections.dart';
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
        .where('status', isEqualTo: RideStatuses.searching)
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

    final requestRef = _db
        .collection(FirestoreCollections.rideRequests)
        .doc(request.requestId);
    final rideRef = _db.collection(FirestoreCollections.rides).doc();
    final driverRef = _db.collection(FirestoreCollections.drivers).doc(uid);
    late Map<String, dynamic> rideData;

    await _db.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      final current = requestSnapshot.data();
      if (current == null) throw StateError('Ride request was not found.');
      if (current['status'] != RideStatuses.searching ||
          current['assignedDriverId'] != uid) {
        throw StateError('This ride request is no longer available.');
      }
      final expiresAt = current['expiresAt'];
      if (expiresAt is Timestamp &&
          expiresAt.toDate().isBefore(DateTime.now())) {
        throw StateError('This ride request has expired.');
      }

      final driverSnapshot = await transaction.get(driverRef);
      final driverData = driverSnapshot.data();
      if (driverData != null && driverData['currentRideId'] != null) {
        throw StateError('You are already on an active ride.');
      }

      rideData = {
        'rideId': rideRef.id,
        'requestId': request.requestId,
        'riderId': request.riderId,
        'driverId': uid,
        'pickupLocation': request.pickupLocation.toMap(),
        'destinationLocation': request.destinationLocation.toMap(),
        'distanceKm': request.distanceKm,
        'estimatedDurationMinutes': request.estimatedDurationMinutes,
        'selectedRideType': request.selectedRideType,
        'estimatedFare': request.estimatedFare,
        'finalFare': null,
        'currency': request.currency,
        'paymentStatus': PaymentStatuses.pending,
        'paymentMethod': request.paymentMethod,
        'status': RideStatuses.accepted,
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
        'startedAt': null,
        'completedAt': null,
        'cancelledAt': null,
      };
      transaction.set(rideRef, rideData);
      transaction.update(requestRef, {
        'status': RideStatuses.accepted,
        'assignedDriverId': uid,
        'assignedRideId': rideRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(driverRef, {
        'currentRideId': rideRef.id,
        'currentRideStatus': RideStatuses.accepted,
        'status': 'busy',
        'isOnline': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    return _tripFromRequest(uid, request, rideId: rideRef.id);
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

      if (data['status'] != RideStatuses.searching ||
          data['assignedDriverId'] != uid) {
        return;
      }
      transaction.update(requestRef, {
        'assignedDriverId': null,
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
    final allowedPrevious = switch (nextStatus) {
      RideStatuses.driverArriving => {RideStatuses.accepted},
      RideStatuses.arrived => {RideStatuses.driverArriving},
      RideStatuses.ongoing => {RideStatuses.arrived},
      RideStatuses.cancelled => {
        RideStatuses.accepted,
        RideStatuses.driverArriving,
        RideStatuses.arrived,
      },
      _ => <String>{},
    };
    if (allowedPrevious.isEmpty) {
      throw StateError('Unsupported ride transition: $nextStatus');
    }

    final rideRef = _db.collection(FirestoreCollections.rides).doc(rideId);
    final requestRef = _db
        .collection(FirestoreCollections.rideRequests)
        .doc(requestId);
    final driverRef = _db.collection(FirestoreCollections.drivers).doc(uid);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(rideRef);
      final data = snapshot.data();
      if (data == null || data['driverId'] != uid) {
        throw StateError('The active ride was not found.');
      }
      if (!allowedPrevious.contains(data['status'])) {
        throw StateError('The ride status changed. Refresh and try again.');
      }

      final rideUpdate = <String, dynamic>{'status': nextStatus};
      if (nextStatus == RideStatuses.ongoing) {
        rideUpdate['startedAt'] = FieldValue.serverTimestamp();
      } else if (nextStatus == RideStatuses.cancelled ||
          nextStatus == 'cancelled_by_rider' ||
          nextStatus == 'cancelled_by_driver') {
        rideUpdate['cancelledAt'] = FieldValue.serverTimestamp();
        if (reason != null) {
          rideUpdate['cancellationReason'] = reason;
        }
      }
      transaction.update(rideRef, rideUpdate);
      transaction.set(requestRef, {
        'status': nextStatus,
        // ignore: use_null_aware_elements
        if (reason != null) 'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(driverRef, {
        'currentRideStatus': nextStatus,
        if (nextStatus == RideStatuses.cancelled) ...{
          'currentRideId': null,
          'status': 'online',
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> completeRide({
    required String uid,
    required DriverTrip trip,
  }) async {
    if (_usePreview) return;
    if (!FirebaseConfig.isAvailable) {
      throw StateError('Firebase is unavailable.');
    }

    await _functions.httpsCallable('completeRideAndSettleEarnings').call({
      'rideId': trip.id,
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
