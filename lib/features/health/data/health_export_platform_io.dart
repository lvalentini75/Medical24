import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';

Future<void> saveHealthCsv(String content, String filename) => SharePlus.instance.share(ShareParams(files: <XFile>[XFile.fromData(Uint8List.fromList(content.codeUnits), mimeType: 'text/csv', name: filename)]));