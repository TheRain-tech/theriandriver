import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/firebase_config.dart';
import '../../firebase/firestore_collections.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/location_service.dart';
import '../../services/auth_service.dart';
import '../../services/driver_profile_service.dart';
import '../models/app_enums.dart';
import '../models/support_ticket.dart';

class DriverSupportRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<SupportTicket> createTicket({
    required String issueType,
    required String description,
    String? screenshotPath,
    UploadProgress? onUploadProgress,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'preview-driver';
    final ticketRef = _db
        .collection(FirestoreCollections.driverSupportTickets)
        .doc();
    final ticketId = ticketRef.id;

    String? storagePath;
    if (screenshotPath != null && FirebaseConfig.isAvailable) {
      final storage = FirebaseStorageService();
      storagePath = await storage.uploadFile(
        file: XFile(screenshotPath),
        path: 'driver_support_tickets/$uid/$ticketId/screenshot.jpg',
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
      await ticketRef.set({
        'ticketId': ticketId,
        'driverId': uid,
        'issueType': issueType,
        'description': description,
        'screenshotPath': storagePath,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return ticket;
  }

  Future<String> createSosAlert() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in before sending an SOS alert.');
    final location =
        LocationService.instance.currentLocation.value ??
        await LocationService.instance.getCurrentLocation();
    final user = AuthService.instance.currentUser;
    final currentRideId =
        DriverProfileService.instance.profile.value.currentRideId;
    final alertRef = _db.collection(FirestoreCollections.sosAlerts).doc();
    if (FirebaseConfig.isAvailable) {
      await alertRef.set({
        'alertId': alertRef.id,
        'driverId': uid,
        'userId': uid,
        'userName': user?.displayName ?? 'Driver',
        'userPhone': user?.phoneNumber ?? '',
        'currentRideId': currentRideId,
        'latitude': location.lat,
        'longitude': location.lng,
        'issueType': 'emergency',
        'message': 'SOS emergency triggered by driver',
        'status': 'active',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return alertRef.id;
  }

  Future<List<SupportTicket>> getTickets() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirebaseConfig.isAvailable) {
      return const [];
    }

    final query = await _db
        .collection(FirestoreCollections.driverSupportTickets)
        .where('driverId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    return query.docs.map((doc) {
      final data = doc.data();
      return SupportTicket(
        id: doc.id,
        driverId: data['driverId']?.toString() ?? '',
        issueType: data['issueType']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        screenshotPath: data['screenshotPath']?.toString(),
        status: enumByName(
          SupportTicketStatus.values,
          data['status'],
          SupportTicketStatus.open,
        ),
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }).toList();
  }
}
