import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/features/health/data/alert_models.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/data/health_repository.dart';
import 'package:medical24/features/health/data/symptom_models.dart';
import 'package:medical24/features/health/data/symptoms_repository.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/features/health/screens/symptom_form_screen.dart';
import 'package:medical24/features/health/widgets/alert_list.dart';
import 'package:medical24/features/health/widgets/symptom_list.dart';
import 'package:medical24/features/home/data/home_models.dart';
import 'package:medical24/features/home/widgets/home_dashboard.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

void main() {
  testWidgets('symptom diary renders three entries', (WidgetTester tester) async {
    final DateTime now = DateTime(2026, 10, 29, 12);
    await tester.pumpWidget(_app(SymptomList(entries: <SymptomEntry>[
      SymptomEntry(id: '1', code: 'headache', severity: 3, occurredAt: now, createdAt: now),
      SymptomEntry(id: '2', code: 'nausea', severity: 2, occurredAt: now, createdAt: now),
      SymptomEntry(id: '3', freeText: 'Fastidio', severity: 1, occurredAt: now.subtract(const Duration(days: 1)), createdAt: now),
    ])));
    expect(find.text('Mal di testa'), findsOneWidget);
    expect(find.text('Nausea'), findsOneWidget);
    expect(find.text('Fastidio'), findsOneWidget);
  });

  testWidgets('symptom form is read only after 24 hours', (WidgetTester tester) async {
    final DateTime old = DateTime.now().subtract(const Duration(hours: 25));
    await tester.pumpWidget(_app(SymptomForm(entry: SymptomEntry(id: '1', code: 'fatigue', severity: 3, occurredAt: old, createdAt: old)), repository: const _FakeSymptomsRepository()));
    expect(find.text('Dopo 24 ore la registrazione non può più essere modificata o eliminata.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Salva'), findsNothing);
  });

  testWidgets('alert center shows critical and warning alerts', (WidgetTester tester) async {
    final DateTime now = DateTime(2026, 10, 29);
    await tester.pumpWidget(_app(HealthAlertList(alerts: <HealthAlert>[
      HealthAlert(id: '1', type: HealthAlertType.critical, code: 'A', level: 'institutional', messageKey: 'alertBiomarkerCriticalHigh', createdAt: now, biomarkerNameIt: 'Glucosio'),
      HealthAlert(id: '2', type: HealthAlertType.warning, code: 'B', level: 'lab', messageKey: 'alertBiomarkerBelowInstitutional', createdAt: now, biomarkerNameIt: 'Emoglobina'),
    ], onOpen: (_) {})));
    expect(find.text('Glucosio'), findsOneWidget);
    expect(find.text('Emoglobina'), findsOneWidget);
    expect(find.text('Contatta il medico'), findsOneWidget);
  });

  for (final Size size in <Size>[const Size(390, 844), const Size(834, 1194), const Size(1200, 1080), const Size(1440, 1080), const Size(1920, 1080)]) {
    testWidgets('full home snapshot at ${size.width.toInt()} breakpoint', (WidgetTester tester) async {
      await _setSize(tester, size);
      await tester.pumpWidget(_app(HomeDashboard(snapshot: _fullSnapshot)));
      expect(find.text('Stato di salute'), findsOneWidget);
      expect(find.text('La tua salute'), findsOneWidget);
      expect(find.text('Documenti recenti'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('phone home uses catalog name and draws a single point', (WidgetTester tester) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app(HomeDashboard(snapshot: _fullSnapshot)));
    await tester.pump();
    expect(find.text('Emocromo completo'), findsWidgets);
    expect(find.text('6690-2'), findsNothing);
    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty home snapshot invites first report upload', (WidgetTester tester) async {
    await tester.pumpWidget(_app(const HomeDashboard(snapshot: HomeSnapshot(values: <HomeValue>[], unreadAlerts: <HealthAlert>[], documentsToReview: <HomeDocument>[], counts: HomeCounts()))));
    expect(find.text('Inizia dal tuo primo referto'), findsOneWidget);
    expect(find.text('Carica il primo referto'), findsOneWidget);
  });
}

final HomeSnapshot _fullSnapshot = HomeSnapshot(
  values: <HomeValue>[
    HomeValue(code: '6690-2', value: 6.2, unit: '10^9/L', effectiveAt: _testDate, flag: ObservationFlag.within),
    HomeValue(code: '2345-7', value: 92, unit: 'mg/dL', effectiveAt: _testDate, flag: ObservationFlag.within),
  ],
  unreadAlerts: <HealthAlert>[],
  documentsToReview: <HomeDocument>[HomeDocument(id: 'doc-1', title: 'Esami', status: 'needs_review')],
  latestDocument: HomeDocument(id: 'doc-2', title: 'Referto', status: 'analyzed'),
  counts: HomeCounts(observations: 2, unreadAlerts: 2, documents: 2, symptoms: 1),
);

final DateTime _testDate = DateTime(2026, 10, 29);

Widget _app(Widget child, {SymptomsRepository? repository}) => ProviderScope(overrides: <Override>[healthRepositoryProvider.overrideWithValue(const _FakeHealthRepository()), if (repository != null) symptomsRepositoryProvider.overrideWithValue(repository)], child: MaterialApp(locale: const Locale('it'), supportedLocales: AppLocalizations.supportedLocales, localizationsDelegates: const <LocalizationsDelegate<dynamic>>[AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], home: Scaffold(body: child)));

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeSymptomsRepository implements SymptomsRepository {
  const _FakeSymptomsRepository();
  @override Future<void> create(SymptomInput input) async {}
  @override Future<void> delete(String id) async {}
  @override Future<SymptomEntry?> get(String id) async => null;
  @override Future<List<SymptomEntry>> list() async => const <SymptomEntry>[];
  @override Future<void> update(String id, SymptomInput input) async {}
}

class _FakeHealthRepository implements HealthRepository {
  const _FakeHealthRepository();
  @override
  Future<List<BiomarkerSummary>> catalog() async => <BiomarkerSummary>[
    BiomarkerSummary(code: '6690-2', nameIt: 'Emocromo completo', nameEn: 'Complete blood count', unit: '10^9/L', latestValue: 6.2, latestAt: _testDate, valueCount: 1),
    BiomarkerSummary(code: '2345-7', nameIt: 'Glucosio nel sangue con denominazione molto lunga', nameEn: 'Blood glucose with a very long name', unit: 'mg/dL', latestValue: 92, latestAt: _testDate, valueCount: 1),
  ];
  @override
  Future<BiomarkerHistoryData> history(String code, {DateTime? from, DateTime? to}) async => BiomarkerHistoryData(points: <BiomarkerPoint>[BiomarkerPoint(id: 'point-1', code: code, at: _testDate, value: code == '6690-2' ? 6.2 : 92, unit: code == '6690-2' ? '10^9/L' : 'mg/dL')], stats: const BiomarkerStats(valueCount: 1), episodes: const <BiomarkerEpisode>[]);
  @override Future<void> insertManualValues(List<ManualObservationInput> values, DateTime effectiveAt) async {}
  @override Future<List<ManualBiomarker>> manualCatalog() async => const <ManualBiomarker>[];
  @override Future<void> setWatch(BiomarkerSummary biomarker, {bool? favorite, bool? tracked}) async {}
  @override Future<List<Map<String, dynamic>>> exportRows() async => const <Map<String, dynamic>>[];
}