import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/firebase_config.dart';
import '../../config/env_config.dart';
import '../../firebase/firestore_collections.dart';
import '../../services/firebase_storage_service.dart';
import '../mock/mock_driver_documents.dart';
import '../mock/mock_driver_vehicles.dart';
import '../models/driver_document.dart';
import '../models/driver_vehicle.dart';

class DriverVehicleRepository {
  DriverVehicleRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  String? get _uid => FirebaseConfig.isAvailable
      ? FirebaseAuth.instance.currentUser?.uid
      : null;

  Future<List<DriverVehicle>> getVehicles() async {
    final uid = _uid;
    if (uid == null || !FirebaseConfig.isAvailable) {
      return EnvConfig.previewMode || FirebaseConfig.useMockFallback
          ? List.unmodifiable(mockDriverVehicles)
          : const [];
    }

    final snapshot = await _db
        .collection(FirestoreCollections.driverVehicles)
        .where('driverId', isEqualTo: uid)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return DriverVehicle.fromJson({...data, 'id': doc.id});
    }).toList();
  }

  Future<List<DriverDocument>> getDocuments() async {
    final uid = _uid;
    if (uid == null || !FirebaseConfig.isAvailable) {
      return EnvConfig.previewMode || FirebaseConfig.useMockFallback
          ? List.unmodifiable(mockDriverDocuments)
          : const [];
    }

    final snapshot = await _db
        .collection(FirestoreCollections.driverDocuments)
        .where('driverId', isEqualTo: uid)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return DriverDocument.fromJson({...data, 'id': doc.id});
    }).toList();
  }

  Future<void> addVehicle(DriverVehicle vehicle) async {
    final uid = _uid;
    if (uid == null) {
      if (EnvConfig.previewMode) return;
      throw StateError('Sign in before adding a vehicle.');
    }

    if (!FirebaseConfig.isAvailable) {
      throw StateError('Firebase is unavailable.');
    }

    final vehicles = await getVehicles();
    final isDefault = vehicles.isEmpty;

    final docRef = _db.collection(FirestoreCollections.driverVehicles).doc();
    await docRef.set({
      'id': docRef.id,
      'driverId': uid,
      'type': vehicle.type,
      'model': vehicle.model,
      'plateNumber': vehicle.plateNumber,
      'plateType': vehicle.plateType,
      'color': vehicle.color,
      'seats': vehicle.seats,
      'isDefault': isDefault,
      'documentStatus': 'pending',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> uploadDocument({
    required String type,
    required String filePath,
    String? vehicleId,
    DateTime? expiresAt,
  }) async {
    final uid = _uid;
    if (uid == null) {
      if (EnvConfig.previewMode) return;
      throw StateError('Sign in before uploading a document.');
    }

    String? storagePath;
    if (FirebaseConfig.isAvailable) {
      final storage = FirebaseStorageService();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          '${type.toLowerCase().replaceAll(' ', '_')}_$timestamp.jpg';
      if (vehicleId != null) {
        storagePath = await storage.uploadFile(
          file: XFile(filePath),
          path: 'vehicle_documents/$uid/$vehicleId/$fileName',
        );
      } else {
        storagePath = await storage.uploadFile(
          file: XFile(filePath),
          path: 'driver_documents/$uid/$fileName',
        );
      }
    }

    final docRef = _db.collection(FirestoreCollections.driverDocuments).doc();
    await docRef.set({
      'id': docRef.id,
      'driverId': uid,
      'vehicleId': vehicleId,
      'type': type,
      'status': 'uploaded',
      'filePath': storagePath ?? filePath,
      'expiresAt': expiresAt?.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
