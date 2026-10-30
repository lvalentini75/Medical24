import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:medical24/core/theme/app_theme.dart';
import 'package:medical24/core/models/user_profile.dart';
import 'package:medical24/core/providers/app_providers.dart';
import 'package:medical24/core/ui/widgets/headers.dart';
import 'package:medical24/core/widgets/app_add_action.dart';
import 'package:medical24/core/widgets/app_shell.dart';
import 'package:medical24/core/widgets/app_breadcrumb.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('it')}) {
  return MaterialApp(
    locale: locale,
    theme: lightTheme,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: ProviderScope(overrides: <Override>[
      myProfileProvider.overrideWith(_TestProfileNotifier.new),
      unreadAlertsProvider.overrideWith((Ref ref) async => 2),
    ], child: child),
  );
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrap(AppShell(
    navigationShell: const Center(child: Text('content')),
    currentIndex: 0,
    onDestinationSelected: (_) {},
  )));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone 390x844 shows the bottom bar', (WidgetTester tester) async {
    await _pumpAt(tester, const Size(390, 844));
    expect(find.byType(M24BottomBar), findsOneWidget);
    expect(find.byType(M24BottomBarItem), findsNWidgets(4));
    expect(find.byType(AppAddFloatingButton), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Salute'), findsOneWidget);
    expect(find.text('Archivio'), findsOneWidget);
    expect(find.text('Cure'), findsOneWidget);
    expect(find.text('Medico'), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(M24AppHeader), findsOneWidget);
    expect(find.byType(AppBreadcrumb), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('tablet 834x1194 shows the navigation rail',
      (WidgetTester tester) async {
    await _pumpAt(tester, const Size(834, 1194));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(M24BottomBar), findsNothing);
    expect(find.byType(AppAddFloatingButton), findsOneWidget);
    expect(find.text('Medico'), findsOneWidget);
    expect(find.byType(M24AppHeader), findsOneWidget);
    expect(find.byType(AppBreadcrumb), findsNothing);
  });

  testWidgets('desktop 1920x1080 shows the fixed side menu',
      (WidgetTester tester) async {
    await _pumpAt(tester, const Size(1920, 1080));
    expect(find.byType(M24BottomBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(M24Sidebar), findsOneWidget);
    expect(find.byType(AppBreadcrumb), findsOneWidget);
    expect(find.text('Panoramica'), findsOneWidget);
    expect(find.text('Impostazioni'), findsOneWidget);
  });

  testWidgets('labels follow the locale', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_wrap(
      AppShell(
        navigationShell: const SizedBox.shrink(),
        currentIndex: 0,
        onDestinationSelected: (_) {},
      ),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);
  });
}

class _TestProfileNotifier extends MyProfileNotifier {
  @override
  Future<UserProfile?> build() async => const UserProfile(id: 'test', fullName: 'Anna Rossi');
}
