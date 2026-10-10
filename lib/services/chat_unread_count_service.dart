import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// The current driver's own unread-message count for one ride's chat, as a live stream - the
/// same `ride_chats/{rideId}.unreadCount.{uid}` field the Rider App reads on its own side
/// (functions-rider-maps' onNewRideChatMessage trigger increments it server-side; RideChatScreen's
/// own markRideChatRead callable resets it back to 0 on open). Centralized here so every chat
/// entry point (RiderCard, go_to_pickup_screen's own chat button) reads the exact same field the
/// exact same way, rather than several slightly-different inline StreamBuilder queries.
Stream<int> watchRideChatUnreadCount(String rideId) {
  if (rideId.isEmpty) return Stream<int>.value(0);
  return FirebaseFirestore.instance
      .collection('ride_chats')
      .doc(rideId)
      .snapshots()
      .map((snapshot) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final unread = snapshot.data()?['unreadCount'];
        if (unread is! Map || uid == null) return 0;
        return (unread[uid] as num?)?.toInt() ?? 0;
      });
}
