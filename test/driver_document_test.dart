import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/data/models/app_enums.dart';
import 'package:theraindriver/data/models/driver_document.dart';
import 'package:theraindriver/services/registration_draft_service.dart';

void main() {
  group('DriverDocument', () {
    test('preserves Fleet invitation document metadata', () {
      final document = DriverDocument.fromJson({
        'id': 'document-1',
        'driverId': 'driver-1',
        'type': 'DRIVERS_LICENSE',
        'status': 'PENDING_VERIFICATION',
        'metadata': {
          'source': 'fleet_invitation',
          'uploadedByFleet': true,
          'originalName': 'licence.pdf',
        },
        'file': {
          'path': 'fleet-driver-invitations/driver-licenses/licence.pdf',
        },
      });

      expect(document.status, DocumentStatus.pending);
      expect(document.source, 'fleet_invitation');
      expect(document.uploadedByFleet, isTrue);
      expect(document.originalName, 'licence.pdf');
      expect(
        document.filePath,
        'fleet-driver-invitations/driver-licenses/licence.pdf',
      );
      expect(document.isReusableFleetEvidence, isTrue);
    });

    test('does not classify an ordinary Driver upload as Fleet-provided', () {
      final document = DriverDocument.fromJson({
        'id': 'document-2',
        'driverId': 'driver-1',
        'type': 'NATIONAL_ID',
        'status': 'VERIFIED',
        'metadata': {'source': 'driver_app'},
      });

      expect(document.status, DocumentStatus.verified);
      expect(document.uploadedByFleet, isFalse);
      expect(document.isReusableFleetEvidence, isFalse);
    });

    test('does not reuse a rejected Fleet file', () {
      final document = DriverDocument.fromJson({
        'id': 'document-3',
        'driverId': 'driver-1',
        'type': 'NATIONAL_ID',
        'status': 'REJECTED',
        'metadata': {'source': 'fleet_invitation'},
        'file': {'path': 'fleet-driver-invitations/national-ids/id.jpg'},
      });

      expect(document.isReusableFleetEvidence, isFalse);
    });

    test('Fleet ID and licence files do not complete missing KYC requirements', () {
      final draft = RegistrationDraft(
        nationalIdPhotoPath: 'fleet/national-id.jpg',
        driverLicencePhotoPath: 'fleet/licence.pdf',
      );

      expect(draft.isComplete, isFalse);
    });

    test('gracefully handles missing or null fields in backend payloads', () {
      final document = DriverDocument.fromJson({
        'id': 'document-4',
        'driverId': null,
        'type': 'NATIONAL_ID_BACK',
        'status': null,
        'metadata': {'source': 'fleet_invitation'},
      });

      expect(document.id, 'document-4');
      expect(document.driverId, isEmpty);
      expect(document.type, 'NATIONAL_ID_BACK');
      expect(document.status, DocumentStatus.notUploaded);
      expect(document.filePath, isNull);
      expect(document.isReusableFleetEvidence, isFalse);
    });
  });
}
