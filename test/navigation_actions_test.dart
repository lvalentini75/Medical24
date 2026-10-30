import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/core/widgets/app_add_action.dart';
import 'package:medical24/core/widgets/app_breadcrumb.dart';
import 'package:medical24/core/ui/widgets/navigation.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/data/health_repository.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

void main() {
  testWidgets('desktop breadcrumb resolves health route labels', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GoRouter router = GoRouter(initialLocation: '/health/values/718-7', routes: <RouteBase>[
      GoRoute(path: '/health/values/:code', builder: (_, __) => const Scaffold(body: AppBreadcrumb())),
      GoRoute(path: '/health', builder: (_, __) => const SizedBox()),
    ]);
    await tester.pumpWidget(ProviderScope(overrides: <Override>[healthRepositoryProvider.overrideWithValue(const _NavigationHealthRepository())], child: _TestApp.router(router)));
    await tester.pumpAndSettle();
    expect(find.text('Salute'), findsOneWidget);
    expect(find.text('I miei valori'), findsOneWidget);
    expect(find.text('Emoglobina'), findsOneWidget);
  });

  testWidgets('add sheet exposes the three available actions', (WidgetTester tester) async {
    await tester.pumpWidget(const _TestApp(home: Scaffold(body: AppAddActionSheet())));
    expect(find.text('Carica un referto'), findsOneWidget);
    expect(find.text('Inserisci un valore'), findsOneWidget);
    expect(find.text('Registra un sintomo'), findsOneWidget);
    expect(find.byType(M24Sheet), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({this.home}) : router = null;
  const _TestApp.router(this.router) : home = null;
  final Widget? home;
  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    const List<LocalizationsDelegate<dynamic>> delegates = <LocalizationsDelegate<dynamic>>[AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate];
    return router == null ? MaterialApp(locale: const Locale('it'), localizationsDelegates: delegates, supportedLocales: AppLocalizations.supportedLocales, home: home) : MaterialApp.router(locale: const Locale('it'), localizationsDelegates: delegates, supportedLocales: AppLocalizations.supportedLocales, routerConfig: router);
  }
}

class _NavigationHealthRepository implements HealthRepository {
  const _NavigationHealthRepository();

  @override
  Future<List<BiomarkerSummary>> catalog() async => const <BiomarkerSummary>[BiomarkerSummary(code: '718-7', nameIt: 'Emoglobina', nameEn: 'Hemoglobin', unit: 'g/dL', flag: ObservationFlag.within)];
  @override
  Future<List<ManualBiomarker>> manualCatalog() async => const <ManualBiomarker>[];
  @override
  Future<BiomarkerHistoryData> history(String code, {DateTime? from, DateTime? to}) async => const BiomarkerHistoryData(points: <BiomarkerPoint>[], stats: BiomarkerStats(), episodes: <BiomarkerEpisode>[]);
  @override
  Future<void> insertManualValues(List<ManualObservationInput> values, DateTime effectiveAt) async {}
  @override
  Future<void> setWatch(BiomarkerSummary biomarker, {bool? favorite, bool? tracked}) async {}
  @override
  Future<List<Map<String, dynamic>>> exportRows() async => const <Map<String, dynamic>>[];
}