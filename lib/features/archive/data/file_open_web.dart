import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:medical24/features/archive/data/picked_raw_file.dart';

/// Opens the browser file dialog and returns the chosen file with its bytes.
///
/// Returns `null` only when the user really cancels the dialog.
Future<RawPickedFile?> openSingleFile({
  required List<String> allowedExtensions,
}) async {
  final web.HTMLInputElement input =
      web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.multiple = false;
  input.accept = allowedExtensions.map((String e) => '.$e').join(',');
  input.style.display = 'none';
  web.document.body?.appendChild(input);

  final Completer<RawPickedFile?> completer = Completer<RawPickedFile?>();
  void finish(RawPickedFile? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  Future<void> handleChange() async {
    final web.FileList? files = input.files;
    if (files == null || files.length == 0) {
      finish(null);
      return;
    }
    final web.File? file = files.item(0);
    if (file == null) {
      finish(null);
      return;
    }
    try {
      final JSArrayBuffer buffer = await file.arrayBuffer().toDart;
      finish(RawPickedFile(name: file.name, bytes: buffer.toDart.asUint8List()));
    } catch (_) {
      finish(null);
    }
  }

  input.addEventListener('change', ((web.Event _) => unawaited(handleChange())).toJS);
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);

  input.click();
  final RawPickedFile? result = await completer.future;
  input.remove();
  return result;
}
