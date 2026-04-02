import 'package:image_picker/image_picker.dart';

enum PickSource { camera, gallery }

abstract class PhotoPicker {
  Future<XFile?> pick(PickSource source);
}

class ImagePickerPhotoPicker implements PhotoPicker {
  final ImagePicker _imagePicker;

  ImagePickerPhotoPicker({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  @override
  Future<XFile?> pick(PickSource source) {
    switch (source) {
      case PickSource.camera:
        return _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 90);
      case PickSource.gallery:
        return _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    }
  }
}
