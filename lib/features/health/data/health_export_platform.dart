export 'health_export_platform_stub.dart'
    if (dart.library.html) 'health_export_platform_web.dart'
    if (dart.library.io) 'health_export_platform_io.dart';