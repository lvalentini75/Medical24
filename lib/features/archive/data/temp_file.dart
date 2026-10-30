/// Cross-platform temporary file for sharing the original of a document.
///
/// On iOS/Android the bytes are written into the system temporary directory
/// (the share sheet needs a real path); on the web they stay in memory.
/// The file is always deleted right after the share sheet closes.
library;

export 'temp_file_stub.dart' if (dart.library.io) 'temp_file_io.dart';
