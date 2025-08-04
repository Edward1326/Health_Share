import 'package:file_picker/file_picker.dart';
import 'dart:io';

class FilePickerService {
  static Future<File?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any, // or FileType.custom with extensions
    );

    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }

    return null; // user canceled
  }
}
