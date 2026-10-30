import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

/// Web: nothing is written to disk, the bytes stay in memory.
Future<XFile> writeTempFile(
  Uint8List bytes, {
  required String name,
  required String mimeType,
}) async =>
    XFile.fromData(bytes, name: name, mimeType: mimeType, length: bytes.length);

/// Web: there is no temporary file to remove.
Future<void> deleteTempFile(XFile file) async {}
