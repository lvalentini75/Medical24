import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical24/features/treatments/data/treatment_models.dart';
import 'package:medical24/features/treatments/providers/treatments_providers.dart';
import 'package:medical24/features/treatments/data/treatments_repository.dart';

void main() {
  test('search, filter and select two treatments for comparison', () async {
    final c = ProviderContainer(overrides: [treatmentsRepositoryProvider.overrideWithValue(_FlowRepo())]);
    addTearDown(c.dispose);
    await c.read(treatmentSearchProvider.notifier).update(const TreatmentFilters(query: 'skin'));
    expect(c.read(treatmentSearchProvider).items, hasLength(2));
    final select = c.read(treatmentCompareSelectionProvider.notifier);
    for (final item in c.read(treatmentSearchProvider).items) select.toggle(item);
    expect(c.read(treatmentCompareSelectionProvider), hasLength(2));
  });
}

class _FlowRepo implements TreatmentsRepository {
  static const values = [TreatmentSummary(id: '1', title: 'Skin A'), TreatmentSummary(id: '2', title: 'Skin B')];
  @override Future<TreatmentSearchResult> search(TreatmentFilters f, {int offset = 0, int limit = 20}) async => const TreatmentSearchResult(items: values, total: 2);
  @override Future<TreatmentFacets> facets(TreatmentFilters f) async => const TreatmentFacets();
  @override Future<TreatmentDetail?> detail(String id) async => null;
  @override Future<List<CompareTreatment>> compare(List<String> ids) async => [];
  @override Future<List<TreatmentReview>> reviews(String id, {int offset = 0, int limit = 20}) async => [];
  @override Future<List<TreatmentSummary>> featured({int limit = 6}) async => values;
  @override Future<List<TreatmentSummary>> favorites() async => values;
  @override Future<bool> toggleFavorite(String id) async => true;
  @override Future<Map<String, dynamic>?> myReview(String id) async => null;
  @override Future<String> submitReview(String id, int rating, Map<String, int> subRatings, String? title, String body) async => 'r';
  @override Future<void> withdrawReview(String id) async {}
}