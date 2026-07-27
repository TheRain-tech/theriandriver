import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../app/therain_driver_app.dart';
import '../config/env_config.dart';
import '../config/firebase_config.dart';
import '../data/repositories/driver_repository.dart';
import '../router/route_names.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final DriverRepository _driverRepository = DriverRepository();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundRideOfferSubscription;
  StreamSubscription<RemoteMessage>? _openedRideOfferSubscription;
  String? _initializedUid;
  bool _rideOfferListenerStarted = false;

  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  Future<void> initializeForDriver(String uid) async {
    if (!FirebaseConfig.isAvailable || _initializedUid == uid) return;
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(uid, token);
      }
      await _tokenSubscription?.cancel();
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => _saveToken(uid, token),
      );
      _initializedUid = uid;
      _startRideOfferListenerIfEnabled();
    } catch (error) {
      debugPrint('Firebase Messaging setup skipped: $error');
    }
  }

  /// Phase 2 (docs/platform/phase-6b/DRIVER_NODE_API_MIGRATION.md): reacts to
  /// the RIDE_REQUEST push node-api/services/ride.service.js#notifyCandidateDrivers
  /// sends for a ride it created directly (POST /rides) - there is no
  /// Firestore ride_requests write for this path at all, so this push is the
  /// only signal a driver ever gets. Only active behind
  /// useNodeApiRideAcceptance (default false); a no-op otherwise, so this
  /// never interferes with the real, live Firestore-bridge flow
  /// (RideRepository/watchIncomingRequest) real drivers use today.
  void _startRideOfferListenerIfEnabled() {
    if (!EnvConfig.useNodeApiRideAcceptance || _rideOfferListenerStarted) return;
    _rideOfferListenerStarted = true;

    _foregroundRideOfferSubscription = FirebaseMessaging.onMessage.listen(_handleRideOfferMessage);
    _openedRideOfferSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleRideOfferMessage);
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleRideOfferMessage(message);
    });
  }

  void _handleRideOfferMessage(RemoteMessage message) {
    if (message.data['type'] != 'RIDE_REQUEST') return;
    final rideId = message.data['rideId']?.toString() ?? '';
    if (rideId.isEmpty) return;
    final navigator = TheRainDriverApp.navigatorKey.currentState;
    navigator?.pushNamed(RouteNames.nodeApiRideOffer, arguments: rideId);
  }

  Future<void> _saveToken(String uid, String token) async {
    await _driverRepository.updateDeviceToken(uid, token);
    // Also persist to users/{uid}/fcmTokens/{tokenId} for backend push delivery.
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(token)
        .set({
          'token': token,
          'platform': 'android',
          'app': 'driver',
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    // node-api/services/notification.service.js#createNotification only ever
    // reads users/{uid}.fcmTokens as an array field directly on the user doc
    // - neither of the two writes above match that shape (a subcollection,
    // and drivers/{uid}.fcmToken singular on a different document), so every
    // push node-api has ever tried to send a driver (ride requests, payment
    // confirmations, fleet report updates, ...) has been silently going
    // nowhere. arrayUnion so multiple devices/reinstalls accumulate without
    // duplicating an existing token.
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clear() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    await _foregroundRideOfferSubscription?.cancel();
    _foregroundRideOfferSubscription = null;
    await _openedRideOfferSubscription?.cancel();
    _openedRideOfferSubscription = null;
    _rideOfferListenerStarted = false;
    _initializedUid = null;
  }
}
