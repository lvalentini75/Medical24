import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/biomarker.dart';
import '../../../core/models/observation.dart';
import '../../archive/providers/archive_providers.dart';
import '../data/analysis_repository.dart';
import '../data/catalog_repository.dart';

/// Single instance of the engine repository.
final Provider<AnalysisRepository> analysisRepositoryProvider =
    Provider<AnalysisRepository>((Ref ref) => const AnalysisRepository());

/// Single instance of the catalog repository.
final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>((Ref ref) => const CatalogRepository());

// ---------------------------------------------------------------------------
// Catalog
// ---------------------------------------------------------------------------

/// Whole board catalog. Institutional content, cached for the session.
final FutureProvider<List<Biomarker>> biomarkerCatalogProvider =
    FutureProvider<List<Biomarker>>(
        (Ref ref) => ref.watch(catalogRepositoryProvider).fetchAll());

/// Catalog indexed by LOINC code, to decorate observations without extra
/// queries.
final FutureProvider<Map<String, Biomarker>> biomarkerByCodeProvider =
    FutureProvider<Map<String, Biomarker>>((Ref ref) async {
  final List<Biomarker> all = await ref.watch(biomarkerCatalogProvider.future);
  return <String, Biomarker>{
    for (final Biomarker b in all) b.code: b,
  };
});

/// One biomarker by code.
final biomarkerProvider = FutureProvider.family<Biomarker?, String>(
    (Ref ref, String code) =>
        ref.watch(catalogRepositoryProvider).fetchByCode(code));

/// Catalog categories, for the filter chips.
final FutureProvider<List<String>> biomarkerCategoriesProvider =
    FutureProvider<List<String>>(
        (Ref ref) => ref.watch(catalogRepositoryProvider).categories());

/// Institutional range of a biomarker for the current subject.
final referenceRangeProvider =
    FutureProvider.family<ReferenceRange?, String>((Ref ref, String code) {
  final String? subject = ref.watch(archiveSubjectIdProvider);
  if (subject == null) return Future<ReferenceRange?>.value();
  return ref
      .watch(catalogRepositoryProvider)
      .resolveReference(subjectId: subject, code: code);
});

// ---------------------------------------------------------------------------
// Extractions
// ---------------------------------------------------------------------------

/// Latest extraction of a document, refreshed on demand.
final documentExtractionProvider =
    FutureProvider.family<Extraction?, String>((Ref ref, String documentId) =>
        ref.watch(analysisRepositoryProvider).latestForDocument(documentId));

/// Every attempt on a document.
final documentExtractionHistoryProvider =
    FutureProvider.family<List<Extraction>, String>((Ref ref,
            String documentId) =>
        ref.watch(analysisRepositoryProvider).historyForDocument(documentId));

/// Realtime state of one extraction: the screen follows classify →
/// extract → normalize without polling.
final extractionStreamProvider =
    StreamProvider.family<Extraction?, String>((Ref ref, String extractionId) =>
        ref.watch(analysisRepositoryProvider).watchExtraction(extractionId));

/// Realtime list of the subject extractions, for the analysis dashboard.
final StreamProvider<List<Extraction>> subjectExtractionsProvider =
    StreamProvider<List<Extraction>>((Ref ref) {
  final String? subject = ref.watch(archiveSubjectIdProvider);
  if (subject == null) return Stream<List<Extraction>>.value(const <Extraction>[]);
  return ref
      .watch(analysisRepositoryProvider)
      .watchSubjectExtractions(subjectId: subject);
});

// ---------------------------------------------------------------------------
// Observations
// ---------------------------------------------------------------------------

/// Current values read from a document.
final documentObservationsProvider =
    FutureProvider.family<List<Observation>, String>((Ref ref,
            String documentId) =>
        ref.watch(analysisRepositoryProvider).observationsForDocument(documentId));

/// Realtime values of a document.
final documentObservationsStreamProvider =
    StreamProvider.family<List<Observation>, String>((Ref ref,
            String documentId) =>
        ref
            .watch(analysisRepositoryProvider)
            .watchDocumentObservations(documentId));

/// Values waiting for confirmation across the whole subject.
final FutureProvider<List<Observation>> pendingReviewProvider =
    FutureProvider<List<Observation>>((Ref ref) {
  final String? subject = ref.watch(archiveSubjectIdProvider);
  if (subject == null) {
    return Future<List<Observation>>.value(const <Observation>[]);
  }
  return ref
      .watch(analysisRepositoryProvider)
      .pendingReview(subjectId: subject);
});

/// Latest value of every biomarker the subject has.
final FutureProvider<List<Observation>> latestObservationsProvider =
    FutureProvider<List<Observation>>((Ref ref) {
  final String? subject = ref.watch(archiveSubjectIdProvider);
  if (subject == null) {
    return Future<List<Observation>>.value(const <Observation>[]);
  }
  return ref
      .watch(analysisRepositoryProvider)
      .latestPerCode(subjectId: subject);
});

/// Full history of one biomarker, oldest first.
final observationHistoryProvider =
    FutureProvider.family<List<Observation>, String>((Ref ref, String code) {
  final String? subject = ref.watch(archiveSubjectIdProvider);
  if (subject == null) {
    return Future<List<Observation>>.value(const <Observation>[]);
  }
  return ref
      .watch(analysisRepositoryProvider)
      .historyForCode(code, subjectId: subject);
});

/// Readings consumed this month and plan limit.
final FutureProvider<AnalysisUsage> analysisUsageProvider =
    FutureProvider<AnalysisUsage>(
        (Ref ref) => ref.watch(analysisRepositoryProvider).analysisUsage());

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

/// Starts, retries and confirms. Every write goes through Postgres
/// functions: nothing clinical is updated in place from the client.
class AnalysisController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AnalysisRepository get _repository => ref.read(analysisRepositoryProvider);

  /// "Analizza" / "Aggiorna": queues the document and runs it right away.
  Future<Extraction?> start(String documentId) async {
    state = const AsyncValue<void>.loading();
    Extraction? extraction;
    state = await AsyncValue.guard<void>(() async {
      extraction = await _repository.startExtraction(documentId);
    });
    _invalidate(documentId);
    return extraction;
  }

  /// "Riprova" after a failure: a brand new attempt.
  Future<Extraction?> retry(String documentId) => start(documentId);

  /// Runs a queued extraction and waits for the outcome.
  Future<Extraction?> run(String extractionId, String documentId, {bool force = false}) async {
    state = const AsyncValue<void>.loading();
    Extraction? extraction;
    state = await AsyncValue.guard<void>(() async {
      extraction = await _repository.runExtraction(extractionId, force: force);
    });
    _invalidate(documentId);
    return extraction;
  }

  /// Step 5: the user confirms the value as read.
  Future<void> confirm(Observation observation) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard<void>(
        () => _repository.confirmObservation(observation.id));
    _invalidate(observation.documentId);
  }

  /// Step 5: the user corrects the value, the unit or the date.
  Future<void> correct(
    Observation observation, {
    double? valueNum,
    String? unit,
    String? valueText,
    DateTime? effectiveAt,
  }) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard<void>(() => _repository.confirmObservation(
          observation.id,
          valueNum: valueNum,
          unit: unit,
          valueText: valueText,
          effectiveAt: effectiveAt,
        ));
    _invalidate(observation.documentId);
  }

  /// Removes a review candidate from current clinical series without deleting history.
  Future<void> discard(Observation observation) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard<void>(() => _repository.discardObservation(observation.id));
    _invalidate(observation.documentId);
  }

  void _invalidate(String? documentId) {
    if (documentId != null) {
      ref.invalidate(documentExtractionProvider(documentId));
      ref.invalidate(documentExtractionHistoryProvider(documentId));
      ref.invalidate(documentObservationsProvider(documentId));
      ref.invalidate(archiveDocumentProvider(documentId));
    }
    ref.invalidate(pendingReviewProvider);
    ref.invalidate(latestObservationsProvider);
    ref.invalidate(analysisUsageProvider);
  }
}

final AsyncNotifierProvider<AnalysisController, void> analysisControllerProvider =
    AsyncNotifierProvider<AnalysisController, void>(AnalysisController.new);
