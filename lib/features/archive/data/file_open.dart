/// Cross-platform single-file selection returning the bytes directly.
///
/// On the web a native `<input type="file">` is used: the file_picker web
/// implementation can report a false cancellation and hide a valid choice.
/// On iOS/Android/desktop file_picker is used as usual.
library;

export 'file_open_web.dart' if (dart.library.io) 'file_open_io.dart';
