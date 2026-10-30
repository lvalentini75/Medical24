import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/data/health_repository.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/features/health/screens/health_values_screen.dart';
import 'package:medical24/features/health/screens/manual_value_screen.dart';
import 'package:medical24/features/health/widgets/biomarker_history.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

void main() {
  const List<Size> sizes = <Size>[Size(390, 844), Size(834, 1194), Size(1920, 1080)];
  final FakeHealthRepository repository = FakeHealthRepository();

  for (final Size size in sizes) {
    testWidgets('values list renders at ${size.width.toInt()}', (WidgetTester tester) async {
      await _pump(tester, size, repository, const HealthValuesScreen());
      expect(find.text('La mia salute'), findsOneWidget);
      expect(find.byType(M24Segmented), findsOneWidget);
      expect(find.text('Glicemia'), findsOneWidget);
      expect(find.text('Creatinina'), findsOneWidget);
      expect(find.text('Colesterolo totale'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('history renders six values and two episodes at ${size.width.toInt()}', (WidgetTester tester) async {
      await _pump(tester, size, repository, const HealthValuesScreen(code: 'GLU'));
      expect(find.byType(M24Table), findsOneWidget);
      if (size.width < 1200) {
        expect(find.text('Episodi fuori soglia'), findsOneWidget);
        expect(find.byType(EpisodeCard), findsNWidgets(2));
      } else {
        expect(find.text('Storico delle rilevazioni'), findsOneWidget);
        expect(find.text('Il valore selezionato'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('phone history shows back arrow and parent subtitle', (WidgetTester tester) async {
    await _pump(tester, const Size(390, 844), repository, const HealthValuesScreen(code: 'GLU'));
    expect(find.byIcon(M24Icons.chevronLeft), findsOneWidget);
    expect(find.text('I miei valori'), findsOneWidget);
  });

  testWidgets('manual form rejects implausible value without saving', (WidgetTester tester) async {
    repository.insertCalls = 0;
    await _pump(tester, const Size(390, 844), repository, const ManualValueScreen(initialCode: '2345-7'));
    await tester.enterText(find.byType(TextFormField).first, '2000');
    await tester.tap(find.text('Salva'));
    await tester.pump();
    expect(find.textContaining('valore plausibile'), findsOneWidget);
    expect(repository.insertCalls, 0);
  });

  for (final Size size in sizes) {
    testWidgets('manual form uses centered M24 card at ${size.width.toInt()}', (WidgetTester tester) async {
      await _pump(tester, size, repository, const ManualValueScreen(initialCode: '2345-7'));
      expect(find.byType(M24Card), findsWidgets);
      expect(find.text('Dati della rilevazione'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pump(WidgetTester tester, Size size, HealthRepository repository, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(overrides: <Override>[healthRepositoryProvider.overrideWithValue(repository)], child: MaterialApp(locale: const Locale('it'), localizationsDelegates: const <LocalizationsDelegate<dynamic>>[AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, home: Scaffold(body: child))));
  await tester.pumpAndSettle();
}

class FakeHealthRepository implements HealthRepository {
  int insertCalls = 0;
  final List<BiomarkerSummary> rows = const <BiomarkerSummary>[
    BiomarkerSummary(code: 'GLU', nameIt: 'Glicemia', nameEn: 'Glucose', unit: 'mg/dL', latestValue: 102, latestAt: null, flag: ObservationFlag.above, valueCount: 6, favorite: true, tracked: true),
    BiomarkerSummary(code: 'CREA', nameIt: 'Creatinina', nameEn: 'Creatinine', unit: 'mg/dL', latestValue: 0.9, flag: ObservationFlag.within, valueCount: 2, essential: true),
    BiomarkerSummary(code: 'CHOL', nameIt: 'Colesterolo totale', nameEn: 'Total cholesterol', unit: 'mg/dL', latestValue: 190, flag: ObservationFlag.within, valueCount: 3),
  ];

  @override
  Future<List<BiomarkerSummary>> catalog() async => rows;

  @override
  Future<List<ManualBiomarker>> manualCatalog() async => const <ManualBiomarker>[
    ManualBiomarker(code: '8480-6', nameIt: 'Pressione sistolica', nameEn: 'Systolic pressure', canonicalUnit: 'mm[Hg]', unitAlternatives: <String, double>{'mmHg': 1}, plausibleMin: 40, plausibleMax: 300),
    ManualBiomarker(code: '8462-4', nameIt: 'Pressione diastolica', nameEn: 'Diastolic pressure', canonicalUnit: 'mm[Hg]', unitAlternatives: <String, double>{'mmHg': 1}, plausibleMin: 20, plausibleMax: 200),
    ManualBiomarker(code: '2345-7', nameIt: 'Glicemia', nameEn: 'Glucose', canonicalUnit: 'mg/dL', unitAlternatives: <String, double>{'mmol/L': 18.016}, plausibleMin: 20, plausibleMax: 1000),
  ];

  @override
  Future<void> insertManualValues(List<ManualObservationInput> values, DateTime effectiveAt) async => insertCalls++;
  @override
  Future<List<Map<String, dynamic>>> exportRows() async => const <Map<String, dynamic>>[];

  @override
  Future<BiomarkerHistoryData> history(String code, {DateTime? from, DateTime? to}) async {
    final DateTime base = DateTime(2026, 1, 1);
    final List<BiomarkerPoint> points = List<BiomarkerPoint>.generate(6, (int index) => BiomarkerPoint(id: 'p$index', code: code, at: base.add(Duration(days: index * 30)), value: 90 + index * 4, unit: 'mg/dL', labLow: 70, labHigh: 100, institutionalLow: 70, institutionalHigh: 99, flag: index < 3 ? ObservationFlag.within : ObservationFlag.above, documentId: 'doc$index', labName: 'Lab'));
    return BiomarkerHistoryData(points: points, stats: BiomarkerStats(minimum: 90, maximum: 110, average: 100, latestValue: 110, latestAt: points.last.at, changeFromPrevious: 4, valueCount: 6), episodes: <BiomarkerEpisode>[
      BiomarkerEpisode(start: points[3].at, end: points[4].at, level: 'above', items: <EpisodeItem>[EpisodeItem(id: points[3].id, at: points[3].at, value: points[3].value), EpisodeItem(id: points[4].id, at: points[4].at, value: points[4].value)]),
      BiomarkerEpisode(start: points[5].at, level: 'above', items: <EpisodeItem>[EpisodeItem(id: points[5].id, at: points[5].at, value: points[5].value)]),
    ]);
  }

  @override
  Future<void> setWatch(BiomarkerSummary biomarker, {bool? favorite, bool? tracked}) async {}
}