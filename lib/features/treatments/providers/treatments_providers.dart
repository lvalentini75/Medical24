import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:medical24/features/treatments/data/treatment_models.dart';
import 'package:medical24/features/treatments/data/treatments_repository.dart';

final Provider<TreatmentsRepository> treatmentsRepositoryProvider = Provider<TreatmentsRepository>((Ref ref) => const SupabaseTreatmentsRepository());
final FutureProvider<List<TreatmentSummary>> featuredTreatmentsProvider = FutureProvider<List<TreatmentSummary>>((Ref ref) => ref.watch(treatmentsRepositoryProvider).featured());
final FutureProvider<List<TreatmentSummary>> favoriteTreatmentsProvider = FutureProvider<List<TreatmentSummary>>((Ref ref) => ref.watch(treatmentsRepositoryProvider).favorites());
final treatmentDetailProvider = FutureProvider.family<TreatmentDetail?, String>((Ref ref, String id) => ref.watch(treatmentsRepositoryProvider).detail(id));
final treatmentReviewsProvider = FutureProvider.family<List<TreatmentReview>, String>((Ref ref, String id) => ref.watch(treatmentsRepositoryProvider).reviews(id));
final myTreatmentReviewProvider = FutureProvider.family<Map<String, dynamic>?, String>((Ref ref, String id) => ref.watch(treatmentsRepositoryProvider).myReview(id));
final treatmentCompareProvider = FutureProvider.family<List<CompareTreatment>, List<String>>((Ref ref, List<String> ids) => ref.watch(treatmentsRepositoryProvider).compare(ids));

class TreatmentSearchState {
  const TreatmentSearchState({this.filters = const TreatmentFilters(), this.items = const [], this.facets = const TreatmentFacets(), this.total = 0, this.loading = false, this.loadingMore = false, this.error});
  final TreatmentFilters filters;
  final List<TreatmentSummary> items;
  final TreatmentFacets facets;
  final int total;
  final bool loading, loadingMore;
  final Object? error;
  TreatmentSearchState copyWith({TreatmentFilters? filters, List<TreatmentSummary>? items, TreatmentFacets? facets, int? total, bool? loading, bool? loadingMore, Object? error, bool clearError = false}) => TreatmentSearchState(filters: filters ?? this.filters, items: items ?? this.items, facets: facets ?? this.facets, total: total ?? this.total, loading: loading ?? this.loading, loadingMore: loadingMore ?? this.loadingMore, error: clearError ? null : error ?? this.error);
}

class TreatmentSearchController extends Notifier<TreatmentSearchState> {
  @override
  TreatmentSearchState build() => const TreatmentSearchState();
  Future<void> initialize(TreatmentFilters filters) async { if (state.filters.toQuery().toString() == filters.toQuery().toString() && state.items.isNotEmpty) return; state = state.copyWith(filters: filters); await refresh(); }
  Future<void> update(TreatmentFilters filters) async { state = state.copyWith(filters: filters); await refresh(); }
  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try { final results = await Future.wait<dynamic>(<Future<dynamic>>[ref.read(treatmentsRepositoryProvider).search(state.filters), ref.read(treatmentsRepositoryProvider).facets(state.filters)]); final TreatmentSearchResult search = results[0] as TreatmentSearchResult; state = state.copyWith(items: search.items, total: search.total, facets: results[1] as TreatmentFacets, loading: false); } catch (error) { state = state.copyWith(loading: false, error: error); }
  }
  Future<void> loadMore() async { if (state.loadingMore || state.items.length >= state.total) return; state = state.copyWith(loadingMore: true); try { final TreatmentSearchResult result = await ref.read(treatmentsRepositoryProvider).search(state.filters, offset: state.items.length); state = state.copyWith(items: <TreatmentSummary>[...state.items, ...result.items], total: result.total, loadingMore: false); } catch (error) { state = state.copyWith(loadingMore: false, error: error); } }
}
final NotifierProvider<TreatmentSearchController, TreatmentSearchState> treatmentSearchProvider = NotifierProvider<TreatmentSearchController, TreatmentSearchState>(TreatmentSearchController.new);

class TreatmentCompareController extends Notifier<List<TreatmentSummary>> {
  @override
  List<TreatmentSummary> build() => const <TreatmentSummary>[];
  bool toggle(TreatmentSummary item) { if (state.any((value) => value.id == item.id)) { state = state.where((value) => value.id != item.id).toList(); return true; } if (state.length >= 4) return false; state = <TreatmentSummary>[...state, item]; return true; }
  void clear() => state = const <TreatmentSummary>[];
}
final NotifierProvider<TreatmentCompareController, List<TreatmentSummary>> treatmentCompareSelectionProvider = NotifierProvider<TreatmentCompareController, List<TreatmentSummary>>(TreatmentCompareController.new);