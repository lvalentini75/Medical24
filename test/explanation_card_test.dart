import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/core/ui/m24_theme.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/features/health/explanations/data/explanation_repository.dart';
import 'package:medical24/features/health/explanations/providers/explanation_providers.dart';
import 'package:medical24/features/health/explanations/widgets/m24_explanation_card.dart';
import 'package:medical24/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('shows the initial action and daily usage', (WidgetTester tester) async {
    await _pump(tester, FakeExplanationRepository());
    expect(find.text('Spiegami questo valore'), findsOneWidget);
    expect(find.textContaining('27 spiegazioni'), findsOneWidget);
  });

  testWidgets('shows a cache hit without invoking the function', (WidgetTester tester) async {
    final FakeExplanationRepository repository = FakeExplanationRepository()..simpleCache = _result('Testo dalla cache.', cached: true);
    await _pump(tester, repository);
    expect(find.text('Testo dalla cache.'), findsOneWidget);
    expect(find.textContaining('Aggiornata al'), findsOneWidget);
    expect(repository.generateCalls, 0);
  });

  testWidgets('generates an explanation successfully', (WidgetTester tester) async {
    final FakeExplanationRepository repository = FakeExplanationRepository()..generated = _result('Nuova spiegazione.');
    await _pump(tester, repository);
    await tester.tap(find.text('Spiegami questo valore'));
    await tester.pumpAndSettle();
    expect(find.text('Nuova spiegazione.'), findsOneWidget);
    expect(find.textContaining("Testo generato dall'IA"), findsOneWidget);
    expect(repository.generateCalls, 1);
  });

  testWidgets('shows filter refusal without retry', (WidgetTester tester) async {
    final FakeExplanationRepository repository = FakeExplanationRepository()..refusal = ExplanationRefusal.filter;
    await _pump(tester, repository);
    await tester.tap(find.text('Spiegami questo valore'));
    await tester.pumpAndSettle();
    expect(find.text('Per questo dato non riusciamo a dare una spiegazione affidabile'), findsOneWidget);
    expect(find.text('Riprova'), findsNothing);
  });

  testWidgets('shows the daily limit refusal', (WidgetTester tester) async {
    final FakeExplanationRepository repository = FakeExplanationRepository()..refusal = ExplanationRefusal.limit;
    await _pump(tester, repository);
    await tester.tap(find.text('Spiegami questo valore'));
    await tester.pumpAndSettle();
    expect(find.text('Hai raggiunto le 30 spiegazioni di oggi'), findsOneWidget);
  });

  testWidgets('retries after a generation error', (WidgetTester tester) async {
    final FakeExplanationRepository repository = FakeExplanationRepository()..failOnce = true..generated = _result('Spiegazione dopo la riprova.');
    await _pump(tester, repository);
    await tester.tap(find.text('Spiegami questo valore'));
    await tester.pumpAndSettle();
    expect(find.text('Riprova'), findsOneWidget);
    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();
    expect(find.text('Spiegazione dopo la riprova.'), findsOneWidget);
    expect(repository.generateCalls, 2);
  });

  testWidgets('register change checks cache before generation', (WidgetTester tester) async {
    final FakeExplanationRepository repository = FakeExplanationRepository()
      ..simpleCache = _result('Testo semplice.', cached: true)
      ..clinicalCache = _result('Testo clinico.', cached: true, level: ExplanationLevel.clinical);
    await _pump(tester, repository);
    await tester.tap(find.text('Clinico'));
    await tester.pumpAndSettle();
    expect(find.text('Testo clinico.'), findsOneWidget);
    expect(repository.generateCalls, 0);
    expect(repository.lookupCalls, 2);
  });

  testWidgets('report CTA stays visible and disabled without confirmed values', (WidgetTester tester) async {
    final FakeExplanationRepository repository = FakeExplanationRepository();
    await _pumpReportCta(tester, repository, confirmed: false);
    expect(find.text('Spiegami questo referto'), findsOneWidget);
    final M24Button button = tester.widget<M24Button>(find.byKey(const Key('report-explanation-cta')));
    expect(button.onPressed, isNull);
  });

  testWidgets('report CTA opens the card and generates missing text', (WidgetTester tester) async {
    final FakeExplanationRepository repository = FakeExplanationRepository()..generated = _result('Spiegazione del referto.');
    await _pumpReportCta(tester, repository, confirmed: true);
    await tester.tap(find.byKey(const Key('report-explanation-cta')));
    await tester.pumpAndSettle();
    expect(find.text('Spiegazione del referto.'), findsOneWidget);
    expect(find.text('Rileggi la spiegazione'), findsOneWidget);
    expect(repository.generateCalls, 1);
  });
}

Future<void> _pump(WidgetTester tester, FakeExplanationRepository repository) async {
  await tester.binding.setSurfaceSize(const Size(700, 900));
  await tester.pumpWidget(ProviderScope(overrides: <Override>[explanationRepositoryProvider.overrideWithValue(repository)], child: MaterialApp(theme: M24Theme.light, locale: const Locale('it'), localizationsDelegates: const <LocalizationsDelegate<dynamic>>[AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, home: const Scaffold(body: SingleChildScrollView(child: Padding(padding: EdgeInsets.all(16), child: M24ExplanationCard(subjectId: 'subject', targetType: ExplanationTargetType.biomarker, targetId: 'GLU')))))));
  await tester.pumpAndSettle();
}

Future<void> _pumpReportCta(WidgetTester tester, FakeExplanationRepository repository, {required bool confirmed}) async {
  await tester.binding.setSurfaceSize(const Size(700, 500));
  await tester.pumpWidget(ProviderScope(overrides: <Override>[explanationRepositoryProvider.overrideWithValue(repository)], child: MaterialApp(theme: M24Theme.light, locale: const Locale('it'), localizationsDelegates: const <LocalizationsDelegate<dynamic>>[AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, home: Scaffold(body: ReportExplanationHarness(confirmed: confirmed)))));
  await tester.pumpAndSettle();
}

class ReportExplanationHarness extends StatefulWidget {
  const ReportExplanationHarness({super.key, required this.confirmed});
  final bool confirmed;

  @override
  State<ReportExplanationHarness> createState() => _ReportExplanationHarnessState();
}

class _ReportExplanationHarnessState extends State<ReportExplanationHarness> {
  final M24ExplanationController controller = M24ExplanationController();

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: <Widget>[
    ReportExplanationButton(controller: controller, enabled: widget.confirmed),
    const SizedBox(height: 600),
    M24ExplanationCard(key: const Key('report-explanation-card'), subjectId: 'subject', targetType: ExplanationTargetType.document, targetId: 'document', available: widget.confirmed, controller: controller),
  ])));
}

ExplanationResult _result(String text, {bool cached = false, ExplanationLevel level = ExplanationLevel.simple}) => ExplanationResult(text: text, level: level, lang: 'it', cached: cached, generatedAt: DateTime(2026, 11, 3, 10), model: 'claude-test');

class FakeExplanationRepository implements ExplanationRepository {
  ExplanationLevel preferred = ExplanationLevel.simple;
  ExplanationResult? simpleCache;
  ExplanationResult? clinicalCache;
  ExplanationResult generated = _result('Generata.');
  ExplanationRefusal? refusal;
  bool failOnce = false;
  int generateCalls = 0;
  int lookupCalls = 0;

  @override
  Future<ExplanationLevel> readPreferredLevel() async => preferred;

  @override
  Future<void> savePreferredLevel(ExplanationLevel level) async => preferred = level;

  @override
  Future<ExplanationUsage> usage(String subjectId) async => const ExplanationUsage(used: 3, maxPerDay: 30);

  @override
  Future<ExplanationResult?> lookup(ExplanationRequest request) async {
    lookupCalls++;
    return request.level == ExplanationLevel.simple ? simpleCache : clinicalCache;
  }

  @override
  Future<ExplanationResult> generate(ExplanationRequest request, {bool force = false}) async {
    generateCalls++;
    if (failOnce) { failOnce = false; throw Exception('network'); }
    if (refusal != null) throw ExplanationRefused(refusal!);
    return generated;
  }
}