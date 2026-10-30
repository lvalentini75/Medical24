import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/core/ui/m24_theme.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/data/health_repository.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/features/health/prevention/data/prevention_models.dart';
import 'package:medical24/features/health/prevention/data/prevention_repository.dart';
import 'package:medical24/features/health/prevention/providers/prevention_providers.dart';
import 'package:medical24/features/health/prevention/screens/prevention_questionnaire_screen.dart';
import 'package:medical24/features/health/prevention/screens/prevention_screen.dart';
import 'package:medical24/l10n/generated/app_localizations.dart';

void main() {
  final PreventionSnapshot snapshot = _snapshot();
  for (final Size size in <Size>[const Size(390, 844), const Size(834, 1194), const Size(1920, 1080)]) {
    testWidgets('prevention controls render at ${size.width}', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_TestApp(child: PreventionContent(snapshot: snapshot, tab: PreventionTab.controls)));
      await tester.pumpAndSettle();
      expect(find.text('Prossimi passi'), findsOneWidget);
      expect(find.text('Mammografia'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('risk cards render at ${size.width}', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_TestApp(child: PreventionContent(snapshot: snapshot, tab: PreventionTab.risks)));
      await tester.pump();
      expect(find.text('Cuore e circolazione'), findsOneWidget);
      expect(find.text('Dati da completare'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wizard blocks missing measures, calculates BMI, saves and returns', (WidgetTester tester) async {
    final _FakePreventionRepository repository = _FakePreventionRepository(_snapshot());
    final _FakeHealthRepository healthRepository = _FakeHealthRepository();
    bool returned = false;
    const QuestionnaireState questionnaire = QuestionnaireState(version: '0.1-draft', questions: <String>[], answers: <String, dynamic>{'waist_cm': 80});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(_TestApp(repository: repository, healthRepository: healthRepository, child: PreventionQuestionnaireForm(questionnaire: questionnaire, onSaved: () => returned = true)));
    for (int i = 0; i < 2; i++) { await tester.tap(find.text('Avanti')); await tester.pump(); }
    expect(find.textContaining('Altezza, Peso'), findsOneWidget);
    expect(tester.widget<M24Button>(find.widgetWithText(M24Button, 'Avanti')).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey<String>('height-field')), '175');
    await tester.enterText(find.byKey(const ValueKey<String>('weight-field')), '70');
    await tester.pump();
    expect(find.text('BMI 22,9'), findsOneWidget);
    await tester.tap(find.text('Avanti'));
    await tester.pump();
    await tester.ensureVisible(find.text('Salva le risposte'));
    await tester.tap(find.text('Salva le risposte'));
    await tester.pumpAndSettle();
    expect(repository.saved, isNotNull);
    expect(repository.saved!['bmi'], 22.9);
    expect(healthRepository.weight, 70);
    expect(returned, isTrue);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child, this.repository, this.healthRepository});
  final Widget child;
  final PreventionRepository? repository;
  final HealthRepository? healthRepository;
  @override
  Widget build(BuildContext context) => ProviderScope(overrides: <Override>[if (repository != null) preventionRepositoryProvider.overrideWithValue(repository!), if (healthRepository != null) healthRepositoryProvider.overrideWithValue(healthRepository!)], child: MaterialApp(theme: M24Theme.light, locale: const Locale('it'), localizationsDelegates: const <LocalizationsDelegate<dynamic>>[AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, home: Scaffold(body: child)));
}

class _FakeHealthRepository implements HealthRepository {
  double? weight;
  @override Future<List<BiomarkerSummary>> catalog() async => const <BiomarkerSummary>[];
  @override Future<List<ManualBiomarker>> manualCatalog() async => const <ManualBiomarker>[];
  @override Future<BiomarkerHistoryData> history(String code, {DateTime? from, DateTime? to}) => throw UnimplementedError();
  @override Future<void> setWatch(BiomarkerSummary biomarker, {bool? favorite, bool? tracked}) async {}
  @override Future<void> insertManualValues(List<ManualObservationInput> values, DateTime effectiveAt) async => weight = values.single.value;
  @override Future<List<Map<String, dynamic>>> exportRows() async => const <Map<String, dynamic>>[];
}

class _FakePreventionRepository implements PreventionRepository {
  _FakePreventionRepository(this.value);
  final PreventionSnapshot value;
  Map<String, dynamic>? saved;
  @override Future<PreventionSnapshot> load({bool refresh = true}) async => value;
  @override Future<void> saveAnswers(Map<String, dynamic> answers, String version) async => saved = answers;
  @override Future<void> completeRecommendation(String id, {String? documentId}) async {}
  @override Future<void> dismissRecommendation(String id, {String? reason}) async {}
  @override Future<void> reopenRecommendation(String id) async {}
}

PreventionSnapshot _snapshot() {
  final DateTime now = DateTime.now();
  PreventionRecommendation recommendation(String id, RecommendationStatus status, DateTime? due) => PreventionRecommendation(id: id, calendarId: 'screening_mammografia', titleKey: 'recommendation_screening_mammografia', reasonKey: 'recommendation_screening_mammografia_reason', category: 'Esami', status: status, origin: 'rule', ruleVersion: 'calendar-draft', dueAt: due, completedAt: status == RecommendationStatus.done ? now : null, dismissedAt: status == RecommendationStatus.dismissed ? now : null);
  RiskScore score(RiskFamily family, double value) => RiskScore(id: family.name, family: family, level: RiskLevel.low, score: value, scoreUnit: family == RiskFamily.cardiovascular ? 'percent_10y' : 'points', inputs: const <String, dynamic>{'smoker': false}, factors: const <String>['smoker'], ruleVersion: '${family.name}-draft', computedAt: now);
  final List<RiskScore> scores = <RiskScore>[score(RiskFamily.cardiovascular, 3), score(RiskFamily.diabetes, 8)];
  return PreventionSnapshot(recommendations: <PreventionRecommendation>[recommendation('future', RecommendationStatus.open, now.add(const Duration(days: 30))), recommendation('due', RecommendationStatus.open, now.subtract(const Duration(days: 1))), recommendation('done', RecommendationStatus.done, now)], risks: scores, riskHistory: scores, questionnaire: const QuestionnaireState(version: '0.1-draft', questions: <String>[], answers: <String, dynamic>{}, latestWeightKg: 70), biomarkerNames: const <String, Map<String, String>>{});
}