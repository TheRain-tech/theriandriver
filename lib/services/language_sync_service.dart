import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_config.dart';
import 'driver_preferences_service.dart';

/// Records the language this driver reads (`users/{uid}.preferredLanguage`). The backend looks it
/// up there when it writes a notification or push for the driver, so a French driver receives French
/// notifications and an English driver English ones - independently of every other user.
/// Best effort and idempotent: a failure never affects the app.
class LanguageSyncService {
  LanguageSyncService._();

  static final LanguageSyncService instance = LanguageSyncService._();

  String? _syncedUid;
  String? _syncedLanguage;

  Future<void> sync({String? uid, bool force = false}) async {
    if (!FirebaseConfig.isAvailable) return;
    try {
      final id = uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (id == null) return;
      final code =
          DriverPreferencesService
                  .instance
                  .preferences
                  .value
                  .locale
                  .languageCode
                  .toLowerCase() ==
              'fr'
          ? 'fr'
          : 'en';
      if (!force && _syncedUid == id && _syncedLanguage == code) return;
      await FirebaseFirestore.instance.collection('users').doc(id).set({
        'preferredLanguage': code,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _syncedUid = id;
      _syncedLanguage = code;
    } catch (error) {
      debugPrint('Language sync skipped: $error');
    }
  }
}
