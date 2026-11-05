import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'package:medical24/features/archive/data/picked_raw_file.dart';

/// Opens the native file dialog and returns the chosen file with its bytes.
Future<RawPickedFile?> openSingleFile({
  required List<String> allowedExtensions,
}) async {
  final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom, allowedExtensions: allowedExtensions);
  if (file == null) return null;
  final Uint8List bytes = await file.readAsBytes();
  return RawPickedFile(name: file.name, bytes: bytes);
}
