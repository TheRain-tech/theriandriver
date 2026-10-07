import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../core/localization/driver_copy.dart';
import '../core/utils/document_upload_policy.dart';

class StorageUploadService {
  const StorageUploadService();

  Future<XFile?> pickDocument({bool allowPdf = false}) async {
    final allowedExtensions = allowPdf
        ? DocumentUploadPolicy.documentExtensions.toList(growable: false)
        : DocumentUploadPolicy.imageExtensions.toList(growable: false);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      withData: true,
    );
    final selected = result?.files.singleOrNull;
    if (selected == null) return null;

    final mimeType = DocumentUploadPolicy.contentTypeFor(selected.name);
    if (selected.path != null) {
      return XFile(selected.path!, name: selected.name, mimeType: mimeType);
    }
    final bytes = selected.bytes;
    if (bytes == null) {
      throw StateError(
        DriverCopy.current.t(
          'The selected file could not be read.',
          'Le fichier sélectionné n\'a pas pu être lu.',
        ),
      );
    }
    return XFile.fromData(bytes, name: selected.name, mimeType: mimeType);
  }
}
