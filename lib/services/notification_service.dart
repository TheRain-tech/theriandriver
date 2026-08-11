import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

import '../app/therain_driver_app.dart';
import '../config/env_config.dart';
import '../config/firebase_config.dart';
import '../data/repositories/driver_repository.dart';
import '../router/route_names.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final DriverRepository _driverRepository = DriverRepository();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundRideOfferSubscription;
  StreamSubscription<RemoteMessage>? _openedRideOfferSubscription;
  String? _initializedUid;
  bool _rideOfferListenerStarted = false;
  bool _localNotificationsInitialized = false;
  final Set<String> _alertedRequestIds = <String>{};

  static const AndroidNotificationChannel _incomingRideChannel =
      AndroidNotificationChannel(
        'incoming_rides',
        'Incoming rides',
        description: 'Urgent notifications for new ride requests.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  Future<void> initializeForDriver(String uid) async {
    if (!FirebaseConfig.isAvailable || _initializedUid == uid) return;
    try {
      await _initializeLocalNotifications();
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
      _startRideOfferListener();
    } catch (error) {
      debugPrint('Firebase Messaging setup skipped: $error');
    }
  }

  /// Receives high-priority ride offers for both supported flows. The live
  /// Firestore-bridge offer contains `requestId`; the older node-api offer
  /// contains only `rideId`. Both paths retain their own server-side
  /// authorization checks when the driver opens or accepts the request.
  void _startRideOfferListener() {
    if (_rideOfferListenerStarted) return;
    _rideOfferListenerStarted = true;

    _foregroundRideOfferSubscription = FirebaseMessaging.onMessage.listen(
      (message) => _handleRideOfferMessage(message),
    );
    _openedRideOfferSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleRideOfferMessage(message, openedByDriver: true),
    );
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleRideOfferMessage(message, openedByDriver: true);
      }
    });
  }

  void _handleRideOfferMessage(
    RemoteMessage message, {
    bool openedByDriver = false,
  }) {
    if (message.data['type'] != 'RIDE_REQUEST') return;
    final requestId = message.data['requestId']?.toString().trim() ?? '';
    if (requestId.isNotEmpty) {
      unawaited(showIncomingRideAlert(requestId));
      if (openedByDriver) {
        TheRainDriverApp.navigatorKey.currentState?.pushNamed(
          RouteNames.rideRequest,
        );
      }
      return;
    }

    // Compatibility for the deliberately gated node-api acceptance flow.
    if (!EnvConfig.useNodeApiRideAcceptance) return;
    final rideId = message.data['rideId']?.toString() ?? '';
    if (rideId.isEmpty) return;
    final navigator = TheRainDriverApp.navigatorKey.currentState;
    navigator?.pushNamed(RouteNames.nodeApiRideOffer, arguments: rideId);
  }

  /// Shows a heads-up Android notification with the system notification sound
  /// and vibration. Firestore and FCM can report the same request; deduping by
  /// request id guarantees the driver hears one alert per offer.
  Future<void> showIncomingRideAlert(String requestId) async {
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty || !_alertedRequestIds.add(normalizedId)) return;
    try {
      await _initializeLocalNotifications();
      await _localNotifications.show(
        id: normalizedId.hashCode,
        title: 'New ride request',
        body: 'A rider is waiting. Tap to review the trip.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'incoming_rides',
            'Incoming rides',
            channelDescription: 'Urgent notifications for new ride requests.',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.call,
            fullScreenIntent: true,
            playSound: true,
            enableVibration: true,
            ongoing: false,
            autoCancel: true,
          ),
        ),
        payload: 'ride_request:$normalizedId',
      );
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.vibrate();
    } catch (error) {
      debugPrint('Incoming ride alert could not be displayed: $error');
      // Do not remove the id here: a failed local notification must not cause
      // repeated audio loops every time Firestore reconnects.
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_incomingRideChannel);
    await android?.requestNotificationsPermission();
    _localNotificationsInitialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload ?? '';
    if (!payload.startsWith('ride_request:')) return;
    final requestId = payload.substring('ride_request:'.length).trim();
    if (requestId.isEmpty) return;
    TheRainDriverApp.navigatorKey.currentState?.pushNamed(
      RouteNames.rideRequest,
    );
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
