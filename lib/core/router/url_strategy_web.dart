import 'package:flutter_web_plugins/url_strategy.dart';

/// Web URLs without "#", so deep links share the same paths as the app.
void configureUrlStrategy() => usePathUrlStrategy();
