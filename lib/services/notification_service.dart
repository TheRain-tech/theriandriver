import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

import '../app/therain_driver_app.dart';
import '../config/env_config.dart';
import '../config/firebase_config.dart';
import '../core/localization/driver_copy.dart';
import '../data/repositories/driver_repository.dart';
import '../router/route_names.dart';
import 'driver_preferences_service.dart';
import 'language_sync_service.dart';

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
  final Set<String> _shownNotificationIds = <String>{};

  static const AndroidNotificationChannel _incomingRideChannel =
      AndroidNotificationChannel(
        'incoming_rides',
        'Incoming rides',
        description: 'Urgent notifications for new ride requests.',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('ride_request'),
        enableVibration: true,
      );
  static const AndroidNotificationChannel _incomingRideSilentChannel =
      AndroidNotificationChannel(
        'incoming_rides_silent',
        'Incoming rides (silent)',
        description: 'Incoming ride requests without sound.',
        importance: Importance.max,
        playSound: false,
        enableVibration: false,
      );

  // Matches node-api's notification.service.js#pushOptionsForType's emergencyChannelId - every
  // SOS-family push (soundKey: "emergency") is routed here regardless of what triggered it
  // (rider or driver), so a driver hears the same distinct, unmistakable alert either way.
  static const String emergencyChannelId = 'therain_emergency';
  static const AndroidNotificationChannel _emergencyChannel =
      AndroidNotificationChannel(
        emergencyChannelId,
        'Emergency alerts',
        description: 'SOS and emergency alerts for your active ride.',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('emergency'),
        enableVibration: true,
      );

  static const AndroidNotificationChannel _accountUpdateChannel =
      AndroidNotificationChannel(
        'driver_account_updates',
        'Driver account updates',
        description: 'Profile, verification, and account status updates.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
  static const AndroidNotificationChannel _accountUpdateSilentChannel =
      AndroidNotificationChannel(
        'driver_account_updates_silent',
        'Driver account updates (silent)',
        description: 'Account updates without sound.',
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
      );

  static const AndroidNotificationChannel _roadAlertChannel =
      AndroidNotificationChannel(
        'road_alerts',
        'Road safety alerts',
        description:
            'Police/speed control, hazard, and road works reports from nearby drivers.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
  static const AndroidNotificationChannel _roadAlertSilentChannel =
      AndroidNotificationChannel(
        'road_alerts_silent',
        'Road safety alerts (silent)',
        description: 'Road safety alerts without sound.',
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
      );

  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  Future<void> initializeForDriver(String uid) async {
    if (!FirebaseConfig.isAvailable || _initializedUid == uid) return;
    try {
      await _initializeLocalNotifications();
    } catch (error) {
      debugPrint('Local notifications setup failed: $error');
    }
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
    }
    try {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: false,
          );
    } catch (error) {
      debugPrint('Foreground notification settings failed: $error');
    }
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveTokenSafely(uid, token);
      }
    } catch (error) {
      debugPrint('Driver notification token registration failed: $error');
    }
    await _tokenSubscription?.cancel();
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => unawaited(_saveTokenSafely(uid, token)),
    );
    _initializedUid = uid;
    _startRideOfferListener();
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
    final upperType = (message.data['type'] ?? '').toString().toUpperCase();
    if (upperType.contains('SOS') || upperType.contains('EMERGENCY')) {
      if (openedByDriver) {
        TheRainDriverApp.navigatorKey.currentState?.pushNamed(
          RouteNames.dashboard,
        );
      } else {
        unawaited(
          showEmergencyAlert(
            title: message.notification?.title ?? 'Emergency alert',
            body:
                message.notification?.body ??
                'An SOS was triggered on your active ride.',
            eventId:
                message.data['notificationId']?.toString() ??
                message.data['eventId']?.toString() ??
                message.messageId,
          ),
        );
      }
      return;
    }
    final type = message.data['type']?.toString().trim() ?? '';
    if (type == 'ROAD_ALERT') {
      if (openedByDriver) {
        TheRainDriverApp.navigatorKey.currentState?.pushNamed(
          RouteNames.dashboard,
        );
      } else {
        unawaited(showRoadAlert(message));
      }
      return;
    }
    if (type != 'RIDE_REQUEST') {
      if (type.isEmpty) return;
      if (openedByDriver) {
        _openAccountUpdate(message.data);
      } else {
        unawaited(showAccountUpdateAlert(message));
      }
      return;
    }
    final requestId = message.data['requestId']?.toString().trim() ?? '';
    if (requestId.isNotEmpty) {
      if (openedByDriver) {
        _alertedRequestIds.add(requestId);
        TheRainDriverApp.navigatorKey.currentState?.pushNamed(
          RouteNames.rideRequest,
        );
      } else {
        unawaited(showIncomingRideAlert(requestId));
      }
      return;
    }

    // Compatibility for the deliberately gated node-api acceptance flow. Every node-api ride
    // (on-demand or a scheduled ride's 8-minutes-before activation - both go through
    // ride.service.js#notifyCandidateDrivers) sends `rideId`, never `requestId`, so this branch
    // is the only place that ever sees those events. It used to navigate here without ever
    // calling showIncomingRideAlert, so the driver got no sound at all - even on a build with
    // the flag on. Sound stays gated behind the same flag as the navigation: with it off, this
    // build has no UI to act on a node-api ride at all, so alerting for one it cannot open would
    // be a notification that goes nowhere, not a fix.
    if (!EnvConfig.useNodeApiRideAcceptance) return;
    final rideId = message.data['rideId']?.toString().trim() ?? '';
    if (rideId.isEmpty) return;
    final navigator = TheRainDriverApp.navigatorKey.currentState;
    if (openedByDriver) {
      _alertedRequestIds.add(rideId);
      navigator?.pushNamed(RouteNames.nodeApiRideOffer, arguments: rideId);
    } else {
      unawaited(showIncomingRideAlert(rideId));
    }
  }

  /// Shows a heads-up Android notification with the system notification sound
  /// and vibration. Firestore and FCM can report the same request; deduping by
  /// request id guarantees the driver hears one alert per offer.
  Future<void> showIncomingRideAlert(String requestId) async {
    if (!DriverPreferencesService
        .instance
        .preferences
        .value
        .rideAlertsEnabled) {
      return;
    }
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty || !_alertedRequestIds.add(normalizedId)) {
      return;
    }
    try {
      await _initializeLocalNotifications();
      await _localNotifications.show(
        id: normalizedId.hashCode,
        title: DriverCopy.current.t('New ride request', 'Nouvelle demande de course'),
        body: DriverCopy.current.t(
          'A rider is waiting. Tap to review the trip.',
          'Un passager attend. Appuyez pour examiner la course.',
        ),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _soundsEnabled ? 'incoming_rides' : 'incoming_rides_silent',
            _soundsEnabled ? 'Incoming rides' : 'Incoming rides (silent)',
            channelDescription: 'Urgent notifications for new ride requests.',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.call,
            fullScreenIntent: true,
            playSound: _soundsEnabled,
            enableVibration: _soundsEnabled,
            ongoing: false,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(
            presentSound: _soundsEnabled,
            sound: _soundsEnabled ? 'ride_request.wav' : null,
          ),
        ),
        payload: 'ride_request:$normalizedId',
      );
      if (_soundsEnabled) {
        try {
          await HapticFeedback.vibrate();
        } on PlatformException catch (error) {
          debugPrint('Ride alert vibration failed: $error');
        }
      }
    } catch (error) {
      _alertedRequestIds.remove(normalizedId);
      debugPrint('Incoming ride alert could not be displayed: $error');
    }
  }

  /// Shows the distinct emergency alert for an SOS-family push received while the app is in
  /// the foreground (background/terminated delivery already renders via the therain_emergency
  /// channel automatically, since node-api sets that channelId on the FCM payload itself).
  Future<void> showEmergencyAlert({
    required String title,
    required String body,
    String? eventId,
  }) async {
    if (!_rememberNotification(eventId)) return;
    try {
      await _initializeLocalNotifications();
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            emergencyChannelId,
            'Emergency alerts',
            channelDescription:
                'SOS and emergency alerts for your active ride.',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            playSound: true,
            enableVibration: true,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(
            presentSound: true,
            sound: 'emergency.wav',
          ),
        ),
      );
      await HapticFeedback.vibrate();
    } catch (error) {
      debugPrint('Emergency alert could not be displayed: $error');
    }
  }

  /// Account/verification pushes use a normal heads-up notification while the
  /// app is foregrounded. When backgrounded, the FCM notification payload is
  /// rendered by Android and [onMessageOpenedApp] follows the same route.
  Future<void> showAccountUpdateAlert(RemoteMessage message) async {
    try {
      await _initializeLocalNotifications();
      final data = message.data;
      final type = data['type']?.toString().trim() ?? 'DRIVER_ACCOUNT_UPDATE';
      final title =
          message.notification?.title ??
          data['title']?.toString() ??
          'TheRain Driver update';
      final body =
          message.notification?.body ??
          data['body']?.toString() ??
          'Open the app to review your account update.';
      final source =
          data['notificationId']?.toString() ??
          data['eventId']?.toString() ??
          message.messageId;
      if (!_rememberNotification(source)) return;
      final localId = source?.hashCode ?? type.hashCode;
      final soundsEnabled = _soundsEnabled;
      await _localNotifications.show(
        id: localId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            soundsEnabled
                ? 'driver_account_updates'
                : 'driver_account_updates_silent',
            soundsEnabled
                ? 'Driver account updates'
                : 'Driver account updates (silent)',
            channelDescription:
                'Profile, verification, and account status updates.',
            importance: Importance.high,
            priority: Priority.high,
            playSound: soundsEnabled,
            enableVibration: soundsEnabled,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(presentSound: soundsEnabled),
        ),
        payload: 'account_update:$type',
      );
    } catch (error) {
      debugPrint('Driver account update could not be displayed: $error');
    }
  }

  /// A road-safety report (police/speed control, hazard, road works) from another nearby
  /// TheRain driver, received while this app is in the foreground. Mirrors
  /// [showAccountUpdateAlert]'s shape exactly, on its own channel so the notification reads as
  /// a road-safety tip rather than an account update.
  Future<void> showRoadAlert(RemoteMessage message) async {
    try {
      await _initializeLocalNotifications();
      final data = message.data;
      final title =
          message.notification?.title ??
          data['title']?.toString() ??
          'Road safety alert';
      final body =
          message.notification?.body ??
          data['body']?.toString() ??
          'Another TheRain driver reported a road condition nearby.';
      final source =
          data['alertId']?.toString() ??
          data['notificationId']?.toString() ??
          message.messageId;
      if (!_rememberNotification(source)) return;
      final localId = source?.hashCode ?? title.hashCode;
      final soundsEnabled = _soundsEnabled;
      await _localNotifications.show(
        id: localId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            soundsEnabled ? 'road_alerts' : 'road_alerts_silent',
            soundsEnabled ? 'Road safety alerts' : 'Road safety alerts (silent)',
            channelDescription:
                'Police/speed control, hazard, and road works reports from nearby drivers.',
            importance: Importance.high,
            priority: Priority.high,
            playSound: soundsEnabled,
            enableVibration: soundsEnabled,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(presentSound: soundsEnabled),
        ),
        payload: 'road_alert',
      );
    } catch (error) {
      debugPrint('Road alert could not be displayed: $error');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails?.notificationResponse;
      if (response != null) _onNotificationResponse(response);
    }
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_incomingRideChannel);
    await android?.createNotificationChannel(_incomingRideSilentChannel);
    await android?.createNotificationChannel(_emergencyChannel);
    await android?.createNotificationChannel(_accountUpdateChannel);
    await android?.createNotificationChannel(_accountUpdateSilentChannel);
    await android?.createNotificationChannel(_roadAlertChannel);
    await android?.createNotificationChannel(_roadAlertSilentChannel);
    await android?.requestNotificationsPermission();
    _localNotificationsInitialized = true;
  }

  bool get _soundsEnabled => DriverPreferencesService
      .instance
      .preferences
      .value
      .notificationSoundsEnabled;

  bool _rememberNotification(String? id) {
    final normalizedId = id?.trim() ?? '';
    if (normalizedId.isEmpty) return true;
    if (!_shownNotificationIds.add(normalizedId)) return false;
    if (_shownNotificationIds.length > 512) {
      _shownNotificationIds.clear();
      _shownNotificationIds.add(normalizedId);
    }
    return true;
  }

  Future<void> previewNotificationSound() async {
    await _initializeLocalNotifications();
    await _localNotifications.show(
      id: 0x445256,
      title: DriverCopy.current.t(
        'Notification sound preview',
        'Aperçu du son de notification',
      ),
      body: DriverCopy.current.t(
        'This is how ride alerts will sound.',
        'Voici le son des alertes de course.',
      ),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'incoming_rides',
          'Incoming rides',
          channelDescription: 'Urgent notifications for new ride requests.',
          importance: Importance.max,
          priority: Priority.max,
          sound: RawResourceAndroidNotificationSound('ride_request'),
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          sound: 'ride_request.wav',
        ),
      ),
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload ?? '';
    if (payload.startsWith('ride_request:')) {
      final requestId = payload.substring('ride_request:'.length).trim();
      if (requestId.isEmpty) return;
      TheRainDriverApp.navigatorKey.currentState?.pushNamed(
        RouteNames.rideRequest,
      );
      return;
    }
    if (payload.startsWith('account_update:')) {
      _openAccountUpdate({'type': payload.substring('account_update:'.length)});
      return;
    }
    if (payload == 'road_alert') {
      TheRainDriverApp.navigatorKey.currentState?.pushNamed(
        RouteNames.dashboard,
      );
    }
  }

  void _openAccountUpdate(Map<String, dynamic> data) {
    final type = data['type']?.toString().toUpperCase() ?? '';
    final route = data['route']?.toString();
    // A cancellation while the driver was away from the app (e.g. navigating in Google Maps)
    // should drop them straight back at a clean dashboard, not a notifications list they then
    // have to back out of - the ride is already gone, there is nothing left to review first.
    // The trip screen's own Firestore listener (see go_to_pickup_screen.dart's
    // _handleCancellation) independently shows the "Trip Cancelled" dialog and clears
    // TripService's active trip state; this only fixes where the notification tap itself lands.
    if (type == 'RIDE_CANCELLED_BY_RIDER' || type == 'RIDE_REQUEST_CANCELLED') {
      TheRainDriverApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        RouteNames.dashboard,
        (_) => false,
      );
      return;
    }
    final destination = type == 'DRIVER_APPROVED'
        ? RouteNames.dashboard
        : type == 'DRIVER_VERIFICATION_PENDING'
        ? RouteNames.pending
        : route == 'driver_application' || type.startsWith('DRIVER_')
        ? RouteNames.application
        : RouteNames.notifications;
    TheRainDriverApp.navigatorKey.currentState?.pushNamed(destination);
  }

  Future<void> _saveToken(String uid, String token) async {
    final tokenId = base64Url.encode(utf8.encode(token));
    await _driverRepository.updateDeviceToken(uid, token);
    // Also persist to users/{uid}/fcmTokens/{tokenId} for backend push delivery.
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(tokenId)
        .set({
          'token': token,
          'platform': switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            _ => 'web',
          },
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
    // Every sign-in / token refresh re-asserts the language, so it survives logout, login and reinstall.
    unawaited(LanguageSyncService.instance.sync(uid: uid, force: true));
  }

  Future<void> _saveTokenSafely(String uid, String token) async {
    try {
      await _saveToken(uid, token);
    } catch (error) {
      debugPrint('Driver notification token write failed: $error');
    }
  }

  Future<void> clear() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    await _foregroundRideOfferSubscription?.cancel();
    _foregroundRideOfferSubscription = null;
    await _openedRideOfferSubscription?.cancel();
    _openedRideOfferSubscription = null;
    _rideOfferListenerStarted = false;
    _shownNotificationIds.clear();
    _alertedRequestIds.clear();
    _initializedUid = null;
  }
}
