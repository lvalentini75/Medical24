import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/features/health/body/data/body_models.dart';
import 'package:medical24/features/health/body/data/body_repository.dart';
import 'package:medical24/features/health/body/providers/body_providers.dart';
import 'package:medical24/features/health/body/screens/body_detail_screen.dart';
import 'package:medical24/features/health/body/screens/body_history_screen.dart';
import 'package:medical24/features/health/body/screens/body_screen.dart';
import 'package:medical24/features/health/body/widgets/body_map.dart';
import 'package:medical24/features/health/body/widgets/body_widgets.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/data/health_repository.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

void main() {
  const List<Size> breakpoints = <Size>[Size(390, 844), Size(834, 1194), Size(1280, 900), Size(1920, 1080)];
  final FakeBodyRepository body = FakeBodyRepository('female');
  final FakeBodyHealthRepository health = FakeBodyHealthRepository();

  for (final Size size in breakpoints) {
    testWidgets('body overview renders 13 mixed areas at ${size.width}', (WidgetTester tester) async {
      await pumpBody(tester, size, body, health, const BodyScreen());
      expect(find.text('Corpo e organi'), findsWidgets);
      expect(find.byType(M24BodyMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('body painter detects liver, heart and intestinal loops', (WidgetTester tester) async {
    final List<String> hits = <String>[];
    await pumpBody(tester, const Size(390, 844), body, health, Center(child: SizedBox(width: 200, child: M24BodyMap(organs: body.organs, onTap: (OrganOverview organ) => hits.add(organ.id), onDoubleTap: (_) {}))));
    final RenderBox box = tester.renderObject(find.byType(M24BodyMap));
    await tester.tapAt(box.localToGlobal(const Offset(80, 196)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(box.localToGlobal(const Offset(106, 150)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(box.localToGlobal(const Offset(96, 222)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(hits, containsAllInOrder(<String>['liver', 'heart', 'gut']));
  });

  testWidgets('list and body share the selected organ provider', (WidgetTester tester) async {
    await pumpBody(tester, const Size(834, 1194), body, health, BodySelectionHarness(organs: body.organs));
    await tester.tap(find.byKey(const ValueKey<String>('organ-row-liver')));
    await tester.pump();
    M24BodyMap map = tester.widget<M24BodyMap>(find.byType(M24BodyMap));
    expect(map.selectedId, 'liver');
    final RenderBox box = tester.renderObject(find.byType(M24BodyMap));
    await tester.tapAt(box.localToGlobal(const Offset(106, 150)));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('selected-heart')), findsOneWidget);
  });

  testWidgets('exploded desktop places labels on both sides', (WidgetTester tester) async {
    await pumpBody(tester, const Size(1920, 1080), body, health, const BodyScreen());
    expect(find.byType(M24ExplodedBodyMap), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('exploded-label-brain')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('exploded-label-heart')), findsOneWidget);
  });

  for (final String sex in <String>['female', 'male']) testWidgets('$sex silhouette follows repository areas', (WidgetTester tester) async {
    final FakeBodyRepository repository = FakeBodyRepository(sex);
    await pumpBody(tester, const Size(390, 844), repository, health, Center(child: SizedBox(width: 200, child: M24BodyMap(organs: repository.organs, onTap: (_) {}, onDoubleTap: (_) {}))));
    final CustomPaint paint = tester.widget<CustomPaint>(find.descendant(of: find.byType(M24BodyMap), matching: find.byType(CustomPaint)).last);
    final M24BodyMapPainter painter = paint.painter! as M24BodyMapPainter;
    expect(painter.sex, sex);
    expect(painter.organs.containsKey('breast'), sex == 'female');
  });

  testWidgets('missing areas use the JSON missing palette', (WidgetTester tester) async {
    await pumpBody(tester, const Size(390, 844), body, health, Center(child: SizedBox(width: 200, child: M24BodyMap(organs: body.organs, onTap: (_) {}, onDoubleTap: (_) {}))));
    final CustomPaint paint = tester.widget<CustomPaint>(find.descendant(of: find.byType(M24BodyMap), matching: find.byType(CustomPaint)).last);
    final M24BodyMapPainter painter = paint.painter! as M24BodyMapPainter;
    expect(painter.organs.values.any((OrganOverview organ) => organ.stressScore == null), isTrue);
    expect(painter.data.missingFill, isNot(painter.data.missingStroke));
  });

  testWidgets('area detail renders present and missing codes', (WidgetTester tester) async {
    await pumpBody(tester, const Size(390, 844), body, health, const BodyDetailScreen(organId: 'heart'));
    expect(find.text('Valori di quest\'area'), findsOneWidget);
    expect(find.text('Colesterolo'), findsOneWidget);
    expect(find.text('Troponina'), findsOneWidget);
    expect(find.text('Dato mancante'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('area history renders comparison and episodes', (WidgetTester tester) async {
    await pumpBody(tester, const Size(834, 1194), body, health, const BodyHistoryScreen(organId: 'heart'));
    expect(find.text('Confronto nel tempo'), findsOneWidget);
    expect(find.text('Episodi di attenzione'), findsOneWidget);
    expect(find.text('Linea del tempo degli stati'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class BodySelectionHarness extends ConsumerWidget {
  const BodySelectionHarness({super.key, required this.organs});
  final List<OrganOverview> organs;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? selected = ref.watch(selectedOrganIdProvider);
    final OrganOverview heart = organs.firstWhere((OrganOverview organ) => organ.id == 'heart');
    final OrganOverview liver = organs.firstWhere((OrganOverview organ) => organ.id == 'liver');
    return Row(children: <Widget>[
      SizedBox(width: 200, child: M24BodyMap(organs: organs, selectedId: selected, onTap: (OrganOverview organ) => ref.read(selectedOrganIdProvider.notifier).state = organ.id, onDoubleTap: (_) {})),
      SizedBox(width: 260, child: Column(children: <Widget>[OrganListRow(organ: liver, selected: selected == liver.id, onTap: () => ref.read(selectedOrganIdProvider.notifier).state = liver.id), if (selected == heart.id) const SizedBox(key: ValueKey<String>('selected-heart'))]))
    ]);
  }
}

Future<void> pumpBody(WidgetTester tester, Size size, BodyRepository body, HealthRepository health, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(overrides: <Override>[bodyRepositoryProvider.overrideWithValue(body), healthRepositoryProvider.overrideWithValue(health)], child: MaterialApp(locale: const Locale('it'), localizationsDelegates: const <LocalizationsDelegate<dynamic>>[AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, home: child)));
  await tester.pumpAndSettle();
}

class FakeBodyRepository implements BodyRepository {
  FakeBodyRepository(this.sex);
  final String sex;
  final DateTime now = DateTime(2026, 10, 30);
  late final List<OrganOverview> organs = <String>['brain', 'thyroid', 'lung', 'heart', 'liver', 'gut', 'metabolism', 'kidney', 'blood', 'immune', 'musculoskeletal', if (sex == 'female') ...<String>['breast', 'reproductive_f'] else ...<String>['prostate', 'reproductive_m']].indexed.map(((int, String) entry) { final int index = entry.$1; final String id = entry.$2; return OrganOverview(id: id, sortOrder: index + 1, nameIt: id == 'heart' ? 'Cuore e circolazione' : id == 'liver' ? 'Fegato' : 'Area ${index + 1}', nameEn: id == 'heart' ? 'Heart and circulation' : id == 'liver' ? 'Liver' : 'Area ${index + 1}', descriptionIt: 'Descrizione dell\'area', descriptionEn: 'Area description', icon: id == 'heart' ? 'heart-pulse' : 'circle-dot', anchorX: .5, anchorY: .08 + index * .06, sex: index < 11 ? 'all' : sex, state: OrganHealthState.values[index % 4], stressScore: index % 4 == 3 ? null : index / 12, confidence: index % 4 == 3 ? 0 : .75, computedAt: now, presentCodes: index % 3, mappedCodes: 2); }).toList(growable: false);
  @override
  Future<OrganRuleVersion?> activeRule() async => const OrganRuleVersion(version: '0.1', notes: 'Draft');
  @override
  Future<List<OrganBiomarker>> biomarkers(String organ) async => <OrganBiomarker>[OrganBiomarker(code: 'CHOL', nameIt: 'Colesterolo', nameEn: 'Cholesterol', unit: 'mg/dL', latestValue: 180, latestAt: now, flag: ObservationFlag.within, weight: 2, isPresent: true), const OrganBiomarker(code: 'TROP', nameIt: 'Troponina', nameEn: 'Troponin', unit: 'ng/L')];
  @override
  Future<int> compute() async => 1;
  @override
  Future<OrganComparison> comparison(String organ) async => OrganComparison(currentState: OrganHealthState.ok, currentAt: now, state6m: OrganHealthState.monitor, at6m: now.subtract(const Duration(days: 180)), state12m: OrganHealthState.attention, at12m: now.subtract(const Duration(days: 365)));
  @override
  Future<List<OrganEpisode>> episodes(String organ) async => <OrganEpisode>[OrganEpisode(start: now.subtract(const Duration(days: 10)), end: now.subtract(const Duration(days: 5)))];
  @override
  Future<List<OrganHistoryEntry>> history(String organ) async => <OrganHistoryEntry>[OrganHistoryEntry(id: 'h1', state: OrganHealthState.monitor, confidence: .5, stressScore: .5, inputs: <OrganHistoryInput>[OrganHistoryInput(code: 'CHOL', observationId: 'o1', flag: ObservationFlag.above, effectiveAt: now, weight: 2)], ruleVersion: '0.1', computedAt: now)];
  @override
  Future<List<OrganOverview>> overview() async => organs;
}

class FakeBodyHealthRepository implements HealthRepository {
  @override
  Future<List<BiomarkerSummary>> catalog() async => const <BiomarkerSummary>[BiomarkerSummary(code: 'CHOL', nameIt: 'Colesterolo', nameEn: 'Cholesterol', unit: 'mg/dL', latestValue: 180, valueCount: 2)];
  @override
  Future<List<Map<String, dynamic>>> exportRows() async => const <Map<String, dynamic>>[];
  @override
  Future<BiomarkerHistoryData> history(String code, {DateTime? from, DateTime? to}) async { final List<BiomarkerPoint> points = <BiomarkerPoint>[BiomarkerPoint(id: '1', code: code, at: DateTime(2026, 1), value: 170, unit: 'mg/dL'), BiomarkerPoint(id: '2', code: code, at: DateTime(2026, 6), value: 180, unit: 'mg/dL')]; return BiomarkerHistoryData(points: points, stats: BiomarkerStats(latestValue: 180, latestAt: points.last.at, valueCount: 2), episodes: const <BiomarkerEpisode>[]); }
  @override
  Future<void> insertManualValues(List<ManualObservationInput> values, DateTime effectiveAt) async {}
  @override
  Future<List<ManualBiomarker>> manualCatalog() async => const <ManualBiomarker>[];
  @override
  Future<void> setWatch(BiomarkerSummary biomarker, {bool? favorite, bool? tracked}) async {}
}