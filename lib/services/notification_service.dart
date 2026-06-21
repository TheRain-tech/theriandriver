import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_config.dart';
import '../data/repositories/driver_repository.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final DriverRepository _driverRepository = DriverRepository();
  StreamSubscription<String>? _tokenSubscription;
  String? _initializedUid;

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
        await _driverRepository.updateDeviceToken(uid, token);
      }
      await _tokenSubscription?.cancel();
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => _driverRepository.updateDeviceToken(uid, token),
      );
      _initializedUid = uid;
    } catch (error) {
      debugPrint('Firebase Messaging setup skipped: $error');
    }
  }

  Future<void> clear() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _initializedUid = null;
  }
}
