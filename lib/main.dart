import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/router/url_strategy.dart';
import 'core/security/app_lock_gate.dart';
import 'package:medical24/core/ui/m24_theme.dart';
import 'core/utils/app_logger.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import 'supabase/supabase_config.dart';

/// Medical 24 — entry point.
///
/// Only the Supabase anon key lives in the client. Everything that costs
/// or carries a secret (Claude, RevenueCat, Stripe, Cloudflare Stream)
/// stays behind Edge Functions.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();

  // Android: block screenshots on clinical screens.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (e) {
      AppLogger.error('main.systemUiMode', e);
    }
  }

  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    AppLogger.error('main.supabaseInit', e);
  }

  runApp(const ProviderScope(child: Medical24App()));
}

class Medical24App extends ConsumerWidget {
  const Medical24App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    final Locale locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Medical 24',
      debugShowCheckedModeBanner: false,
      theme: M24Theme.light,
      darkTheme: M24Theme.dark,
      themeMode: ThemeMode.system,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (BuildContext context, Widget? child) => AppLockGate(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
