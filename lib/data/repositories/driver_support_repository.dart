import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/firebase_config.dart';
import '../../firebase/firestore_collections.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/auth_service.dart';
import '../../services/driver_profile_service.dart';
import '../models/app_enums.dart';
import '../models/support_ticket.dart';

class DriverSupportRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Writes to the same `support_tickets` collection node-api's
  /// support.service.js actually reads (see FirestoreCollections.supportTickets'
  /// doc comment) - the old driverSupportTickets collection this used to
  /// write to has no reader on the admin side at all, so every driver
  /// support ticket filed through it was invisible to every admin. Field
  /// names/status casing match support.service.js#createTicket/normalizeTicket
  /// so this renders correctly in the admin Support page, not just becomes
  /// queryable.
  Future<SupportTicket> createTicket({
    required String issueType,
    required String description,
    String? screenshotPath,
    UploadProgress? onUploadProgress,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'preview-driver';
    final profile = DriverProfileService.instance.profile.value;
    final ticketRef = _db.collection(FirestoreCollections.supportTickets).doc();
    final ticketId = ticketRef.id;

    String? storagePath;
    if (screenshotPath != null && FirebaseConfig.isAvailable) {
      final storage = FirebaseStorageService();
      storagePath = await storage.uploadFile(
        file: XFile(screenshotPath),
        path: 'support_tickets/$uid/$ticketId/screenshot.jpg',
        onProgress: onUploadProgress,
      );
    }

    final ticket = SupportTicket(
      id: ticketId,
      driverId: uid,
      issueType: issueType,
      description: description,
      status: SupportTicketStatus.open,
      createdAt: DateTime.now(),
      screenshotPath: storagePath ?? screenshotPath,
    );

    if (FirebaseConfig.isAvailable) {
      final user = AuthService.instance.currentUser;
      await ticketRef.set({
        // Canonical fields support.service.js#normalizeTicket reads.
        'requesterId': uid,
        'requesterName': user?.displayName ?? 'Driver',
        'requesterPhone': user?.phoneNumber,
        'requesterType': 'driver',
        'subject': issueType,
        'category': issueType,
        'description': description,
        'status': 'OPEN',
        'priority': 'NORMAL',
        'regionId': profile.regionId,
        'source': 'driver_app',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'messages': [
          {
            'authorId': uid,
            'authorRole': 'driver',
            'body': description,
            'internal': false,
            'at': DateTime.now().toIso8601String(),
          },
        ],
        // Driver-app-specific fields this repo's own getTickets() below reads.
        'ticketId': ticketId,
        'driverId': uid,
        'issueType': issueType,
        'screenshotPath': storagePath,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return ticket;
  }

  /// Reads from both the current `support_tickets` collection and the old
  /// `driver_support_tickets` one, so a driver who filed tickets before this
  /// fix still sees their history - new tickets only ever go to the former.
  Future<List<SupportTicket>> getTickets() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirebaseConfig.isAvailable) {
      return const [];
    }

    final results = await Future.wait([
      _db
          .collection(FirestoreCollections.supportTickets)
          .where('driverId', isEqualTo: uid)
          .get(),
      _db
          .collection(FirestoreCollections.driverSupportTickets)
          .where('driverId', isEqualTo: uid)
          .get(),
    ]);

    final tickets = results.expand((query) => query.docs).map((doc) {
      final data = doc.data();
      return SupportTicket(
        id: doc.id,
        driverId: data['driverId']?.toString() ?? '',
        issueType:
            data['issueType']?.toString() ?? data['category']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        screenshotPath: data['screenshotPath']?.toString(),
        status: enumByName(
          SupportTicketStatus.values,
          (data['status']?.toString() ?? '').toLowerCase(),
          SupportTicketStatus.open,
        ),
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return tickets;
  }
}
