import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/env_config.dart';
import '../../config/firebase_config.dart';
import '../../core/utils/document_upload_policy.dart';
import '../../services/api_client.dart';
import '../../services/driver_profile_service.dart';
import '../mock/mock_driver_documents.dart';
import '../mock/mock_driver_vehicles.dart';
import '../models/driver_document.dart';
import '../models/driver_vehicle.dart';

/// A vehicle a driver registers must land in node-api's own authoritative `vehicles` collection
/// (the same one Super Admin/Regional Admin's Vehicle Management, Vehicle Assignment, and the
/// ride/dispatch system all already read) - not a second, disconnected collection this app alone
/// can see. Every call here goes through node-api's real REST endpoints (ApiClient), never a
/// direct Firestore write, for exactly that reason.
class DriverVehicleRepository {
  DriverVehicleRepository();

  String? get _uid => FirebaseConfig.isAvailable
      ? FirebaseAuth.instance.currentUser?.uid
      : null;

  Future<List<DriverVehicle>> getVehicles() async {
    if (_uid == null) {
      return EnvConfig.previewMode || FirebaseConfig.useMockFallback
          ? List.unmodifiable(mockDriverVehicles)
          : const [];
    }
    final data = await ApiClient.instance.get('/vehicles/mine');
    final rows = data is List ? data : const [];
    return rows
        .whereType<Map>()
        .map((row) => DriverVehicle.fromJson(row.cast<String, dynamic>()))
        .toList();
  }

  Future<List<DriverDocument>> getDocuments() async {
    final uid = _uid;
    if (uid == null) {
      return EnvConfig.previewMode || FirebaseConfig.useMockFallback
          ? List.unmodifiable(mockDriverDocuments)
          : const [];
    }
    final results = await Future.wait([
      _driverLevelDocuments(uid),
      _vehiclePhotos(),
    ]);
    return [...results[0], ...results[1]];
  }

  Future<List<DriverDocument>> _driverLevelDocuments(String uid) async {
    try {
      final data = await ApiClient.instance.get('/drivers/$uid/documents');
      final rows = data is Map ? data['documents'] : null;
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map((row) => DriverDocument.fromJson(row.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<DriverDocument>> _vehiclePhotos() async {
    try {
      final vehicles = await getVehicles();
      if (vehicles.isEmpty) return const [];
      final vehicleId = vehicles.first.id;
      final data = await ApiClient.instance.get('/vehicles/$vehicleId/documents');
      final rows = data is List ? data : const [];
      return rows
          .whereType<Map>()
          .where((row) => row['type'] == 'photo')
          .map(
            (row) => DriverDocument.fromJson({
              ...row.cast<String, dynamic>(),
              // vehicle.service.js#listDocuments doesn't carry driverId on the photo doc itself -
              // this repository is always scoped to the signed-in driver, so it's safe to stamp.
              'driverId': _uid,
              'type': 'Vehicle Photos',
              'status': row['approvalStatus'] ?? 'VERIFIED',
            }),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> addVehicle(DriverVehicle vehicle) async {
    if (_uid == null) {
      if (EnvConfig.previewMode) return;
      throw StateError('Sign in before adding a vehicle.');
    }
    final regionId = DriverProfileService.instance.profile.value.regionId;
    if (regionId == null || regionId.isEmpty) {
      throw StateError(
        'Your account has no assigned region yet. Contact support before adding a vehicle.',
      );
    }
    final parts = vehicle.model.trim().split(RegExp(r'\s+'));
    final make = parts.isNotEmpty ? parts.first : vehicle.model;
    final model = parts.length > 1 ? parts.skip(1).join(' ') : vehicle.model;
    await ApiClient.instance.post(
      '/vehicles',
      body: {
        'make': make,
        'model': model,
        'plateNumber': vehicle.plateNumber,
        'color': vehicle.color,
        'regionId': regionId,
        'metadata': {
          'serviceTier': vehicle.type,
          'plateType': vehicle.plateType,
        },
      },
    );
  }

  /// [vehicleId] is required for vehicle-scoped types ('Vehicle Photos') and ignored for
  /// driver-scoped ones (National ID, Driver licence, Insurance, Road Licence, Fitness
  /// Certificate) - those always upload against the signed-in driver themselves via
  /// POST /drivers/me/documents/:type, matching node-api's DRIVER_DOCUMENT_TYPES enum.
  Future<void> uploadDocument({
    required String type,
    required XFile file,
    String? vehicleId,
    DateTime? expiresAt,
  }) async {
    if (_uid == null) {
      if (EnvConfig.previewMode) return;
      throw StateError('Sign in before uploading a document.');
    }
    final bytes = await file.readAsBytes();
    DocumentUploadPolicy.validate(fileName: file.name, bytes: bytes);

    if (type == 'Vehicle Photos') {
      final ownVehicles = vehicleId == null ? await getVehicles() : const <DriverVehicle>[];
      final targetVehicleId = vehicleId ?? (ownVehicles.isEmpty ? null : ownVehicles.first.id);
      if (targetVehicleId == null) {
        throw StateError('Add a vehicle before uploading vehicle photos.');
      }
      await ApiClient.instance.postMultipart(
        '/vehicles/$targetVehicleId/documents/photo',
        bytes: bytes,
        filename: file.name,
      );
      return;
    }

    final nodeApiType = switch (type) {
      'National ID' => 'NATIONAL_ID',
      'Driver licence' => 'DRIVERS_LICENSE',
      'Insurance' => 'INSURANCE_CERTIFICATE',
      'Road Licence' => 'VEHICLE_REGISTRATION',
      'Fitness Certificate' => 'VEHICLE_INSPECTION',
      _ => type.toUpperCase().replaceAll(' ', '_'),
    };
    await ApiClient.instance.postMultipart(
      '/drivers/me/documents/$nodeApiType',
      bytes: bytes,
      filename: file.name,
      fields: expiresAt != null ? {'expiresAt': expiresAt.toIso8601String()} : null,
    );
  }
}
