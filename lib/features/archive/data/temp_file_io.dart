import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';

/// iOS/Android/desktop: the original is written into the system temporary
/// directory so the share sheet can read it, then deleted by the caller.
Future<XFile> writeTempFile(
  Uint8List bytes, {
  required String name,
  required String mimeType,
}) async {
  final Directory dir = await getTemporaryDirectory();
  final Directory folder =
      Directory('${dir.path}/medical24_share')..createSync(recursive: true);
  final File file = File('${folder.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return XFile(file.path, name: name, mimeType: mimeType, length: bytes.length);
}

Future<void> deleteTempFile(XFile file) async {
  try {
    final File handle = File(file.path);
    if (handle.existsSync()) await handle.delete();
  } catch (_) {
    // A leftover temporary file is not an error the user needs to see.
  }
}
