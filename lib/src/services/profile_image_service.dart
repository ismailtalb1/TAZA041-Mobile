import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';

class ProfileImageService {
  ProfileImageService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<CroppedFile?> pickAndCrop({
    required ImageSource source,
    required String title,
  }) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 95,
      maxWidth: 2400,
    );
    if (image == null) return null;

    return ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      maxWidth: 1200,
      maxHeight: 1200,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: TazaColors.darkBg,
          toolbarWidgetColor: TazaColors.textLight,
          activeControlsWidgetColor: TazaColors.accent,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: title,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
  }
}
