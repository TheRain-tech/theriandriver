import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../config/env_config.dart';
import '../../config/firebase_config.dart';
import '../../firebase/firestore_collections.dart';
import '../mock/mock_driver_notifications.dart';
import '../models/driver_notification.dart';

class DriverNotificationRepository {
  DriverNotificationRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;
  String? get _uid => FirebaseConfig.isAvailable
      ? FirebaseAuth.instance.currentUser?.uid
      : null;

  Stream<List<DriverNotification>> watchNotifications() {
    final uid = _uid;
    if (uid == null || !FirebaseConfig.isAvailable) {
      return Stream.value(
        EnvConfig.previewMode || FirebaseConfig.useMockFallback
            ? List.unmodifiable(mockDriverNotifications)
            : const [],
      );
    }
    return _db
        .collection(FirestoreCollections.notifications)
        .where('recipientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) =>
                    DriverNotification.fromMap(document.data(), document.id),
              )
              .toList(growable: false),
        );
  }

  Future<List<DriverNotification>> getNotifications() =>
      watchNotifications().first;

  Future<void> markAsRead(String notificationId) async {
    if (_uid == null || !FirebaseConfig.isAvailable) return;
    await _db
        .collection(FirestoreCollections.notifications)
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    final uid = _uid;
    if (uid == null || !FirebaseConfig.isAvailable) return;
    final query = await _db
        .collection(FirestoreCollections.notifications)
        .where('recipientId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final document in query.docs) {
      batch.update(document.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
