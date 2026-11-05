import 'dart:typed_data';

/// Raw result of the system file selection: name plus bytes already in memory.
class RawPickedFile {
  const RawPickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}
