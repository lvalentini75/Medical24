import 'package:flutter/foundation.dart';

/// Logger that never records personal or clinical data.
///
/// Only event names, table names and error codes may be logged. Values,
/// names, emails and document content must never be passed here.
class AppLogger {
  const AppLogger._();

  static void event(String name, {Map<String, Object?>? meta}) {
    if (!kDebugMode) return;
    debugPrint('[medical24] $name${meta == null ? '' : ' $meta'}');
  }

  static void error(String where, Object error, [StackTrace? stack]) {
    debugPrint('[medical24][error] $where: ${_safe(error)}');
    if (stack != null && kDebugMode) debugPrintStack(stackTrace: stack);
  }

  /// Keeps only the error type and code, never the payload.
  static String _safe(Object error) {
    final String text = error.toString();
    return text.length > 200 ? '${text.substring(0, 200)}…' : text;
  }
}
