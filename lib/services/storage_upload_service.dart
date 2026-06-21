import 'package:image_picker/image_picker.dart';

class StorageUploadService {
  StorageUploadService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<XFile?> pickDocument() =>
      _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
}
