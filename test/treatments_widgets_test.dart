import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/core/ui/m24_theme.dart';
import 'package:medical24/features/treatments/data/treatment_models.dart';
import 'package:medical24/features/treatments/data/treatments_repository.dart';
import 'package:medical24/features/treatments/providers/treatments_providers.dart';
import 'package:medical24/features/treatments/widgets/treatment_widgets.dart';
import 'package:medical24/l10n/generated/app_localizations.dart';

void main() {
  const TreatmentSummary rated = TreatmentSummary(id: '1', title: 'Percorso A', facilityName: 'Centro demo', ratingAverage: 4.5, ratingCount: 12);
  const TreatmentSummary unrated = TreatmentSummary(id: '2', title: 'Percorso B');

  testWidgets('card renders with and without rating', (WidgetTester tester) async {
    await tester.pumpWidget(const _TestApp(child: SingleChildScrollView(child: Column(children: <Widget>[TreatmentCard(treatment: rated), TreatmentCard(treatment: unrated)]))));
    expect(find.textContaining('4,5'), findsOneWidget);
    expect(find.text('Nessuna recensione'), findsOneWidget);
  });

  test('filter updates count from overridden provider data', () async {
    final ProviderContainer container = ProviderContainer(overrides: <Override>[treatmentsRepositoryProvider.overrideWithValue(_FakeTreatmentsRepository())]);
    addTearDown(container.dispose);
    await container.read(treatmentSearchProvider.notifier).update(const TreatmentFilters(scope: 'terapia'));
    expect(container.read(treatmentSearchProvider).total, 1);
    await container.read(treatmentSearchProvider.notifier).update(const TreatmentFilters());
    expect(container.read(treatmentSearchProvider).total, 2);
  });

  test('comparison selection enforces a limit of four', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final TreatmentCompareController controller = container.read(treatmentCompareSelectionProvider.notifier);
    for (int i = 0; i < 4; i++) expect(controller.toggle(TreatmentSummary(id: '$i', title: 'Cura $i')), isTrue);
    expect(controller.toggle(const TreatmentSummary(id: '5', title: 'Una cura in più')), isFalse);
    expect(container.read(treatmentCompareSelectionProvider), hasLength(4));
  });

  testWidgets('review form shows counter and mapped RPC error', (WidgetTester tester) async {
    await tester.pumpWidget(_TestApp(repository: _FakeTreatmentsRepository(reviewError: true), child: const SingleChildScrollView(child: TreatmentReviewForm(treatmentId: '1'))));
    await tester.tap(find.descendant(of: find.byType(StarSelector).first, matching: find.byType(IconButton)).first);
    await tester.enterText(find.byType(TextField).last, 'Esperienza descritta con abbastanza dettagli.');
    await tester.pump();
    expect(find.textContaining('/2000'), findsOneWidget);
    await tester.tap(find.text('Invia recensione'));
    await tester.pumpAndSettle();
    expect(find.text('Non inserire link nella recensione.'), findsOneWidget);
  });

  testWidgets('relative review date covers hours days and absolute dates', (WidgetTester tester) async {
    final now = DateTime(2026, 6, 15, 12);
    await tester.pumpWidget(_TestApp(child: Column(children: <Widget>[
      TreatmentRelativeDate(date: now.subtract(const Duration(hours: 2)), now: now),
      TreatmentRelativeDate(date: now.subtract(const Duration(days: 3)), now: now),
      TreatmentRelativeDate(date: now.subtract(const Duration(days: 31)), now: now)
    ])));
    expect(find.text('2 ore fa'), findsOneWidget);
    expect(find.text('3 giorni fa'), findsOneWidget);
    expect(find.textContaining('15 mag'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child, this.repository});
  final Widget child;
  final TreatmentsRepository? repository;
  @override
  Widget build(BuildContext context) => ProviderScope(overrides: <Override>[if (repository != null) treatmentsRepositoryProvider.overrideWithValue(repository!)], child: MaterialApp(theme: M24Theme.light, locale: const Locale('it'), localizationsDelegates: const <LocalizationsDelegate<dynamic>>[AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, home: Scaffold(body: child)));
}

class _FakeTreatmentsRepository implements TreatmentsRepository {
  _FakeTreatmentsRepository({this.reviewError = false});
  final bool reviewError;
  static const List<TreatmentSummary> values = <TreatmentSummary>[TreatmentSummary(id: '1', title: 'Terapia', scope: 'terapia'), TreatmentSummary(id: '2', title: 'Prevenzione', scope: 'prevenzione')];
  @override Future<TreatmentSearchResult> search(TreatmentFilters filters, {int offset = 0, int limit = 20}) async { final List<TreatmentSummary> result = filters.scope == null ? values : values.where((item) => item.scope == filters.scope).toList(); return TreatmentSearchResult(items: result, total: result.length); }
  @override Future<TreatmentFacets> facets(TreatmentFilters filters) async => const TreatmentFacets(total: 2, scope: <String, int>{'terapia': 1, 'prevenzione': 1});
  @override Future<TreatmentDetail?> detail(String id) async => null;
  @override Future<List<CompareTreatment>> compare(List<String> ids) async => const <CompareTreatment>[];
  @override Future<List<TreatmentReview>> reviews(String id, {int offset = 0, int limit = 20}) async => const <TreatmentReview>[];
  @override Future<List<TreatmentSummary>> featured({int limit = 6}) async => values;
  @override Future<List<TreatmentSummary>> favorites() async => values;
  @override Future<bool> toggleFavorite(String id) async => true;
  @override Future<Map<String, dynamic>?> myReview(String id) async => null;
  @override Future<String> submitReview(String id, int rating, Map<String, int> subRatings, String? title, String body) async { if (reviewError) throw Exception('url_not_allowed'); return 'review'; }
  @override Future<void> withdrawReview(String id) async {}
}