import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical24/features/treatments/data/treatment_models.dart';
import 'package:medical24/features/treatments/providers/treatments_providers.dart';
import 'package:medical24/features/treatments/data/treatments_repository.dart';

void main() {
  test('empty and filtered states are exposed by the search controller', () async {
    final c = ProviderContainer(overrides: [treatmentsRepositoryProvider.overrideWithValue(_Repo())]);
    addTearDown(c.dispose);
    await c.read(treatmentSearchProvider.notifier).update(const TreatmentFilters(scope: 'missing'));
    expect(c.read(treatmentSearchProvider).items, isEmpty);
    expect(c.read(treatmentSearchProvider).total, 0);
    await c.read(treatmentSearchProvider.notifier).update(const TreatmentFilters(scope: 'therapy'));
    expect(c.read(treatmentSearchProvider).total, 1);
  });
}

class _Repo implements TreatmentsRepository {
  @override Future<TreatmentSearchResult> search(TreatmentFilters f, {int offset = 0, int limit = 20}) async { final values = [const TreatmentSummary(id: '1', title: 'A', scope: 'therapy')].where((x) => f.scope == null || x.scope == f.scope).toList(); return TreatmentSearchResult(items: values, total: values.length); }
  @override Future<TreatmentFacets> facets(TreatmentFilters f) async => const TreatmentFacets();
  @override Future<TreatmentDetail?> detail(String id) async => null;
  @override Future<List<CompareTreatment>> compare(List<String> ids) async => [];
  @override Future<List<TreatmentReview>> reviews(String id, {int offset = 0, int limit = 20}) async => [];
  @override Future<List<TreatmentSummary>> featured({int limit = 6}) async => [];
  @override Future<List<TreatmentSummary>> favorites() async => [];
  @override Future<bool> toggleFavorite(String id) async => true;
  @override Future<Map<String, dynamic>?> myReview(String id) async => null;
  @override Future<String> submitReview(String id, int rating, Map<String, int> subRatings, String? title, String body) async => 'id';
  @override Future<void> withdrawReview(String id) async {}
}