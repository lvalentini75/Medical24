import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/observation.dart';
import '../../../core/utils/app_logger.dart';
import '../../../supabase/supabase_config.dart';

/// Single entry point to `public.extractions` and `public.observations`.
///
/// No Supabase query of the engine lives outside this class and no access
/// filter is written here: RLS decides, through `can_access_subject`.
/// Writes never happen with a plain update: `observations` is append-only,
/// so a correction goes through `confirm_observation()`.
class AnalysisRepository {
  const AnalysisRepository();

  static const String _extractions = 'extractions';
  static const String _observations = 'observations';

  SupabaseClient get _db => SupabaseConfig.client;

  String get _uid {
    final String? uid = SupabaseConfig.currentUserId;
    if (uid == null) throw AppFailure.unauthorized;
    return uid;
  }

  // -------------------------------------------------------------------------
  // Extractions
  // -------------------------------------------------------------------------

  /// Puts a document in the queue (`start_extraction`) and asks the
  /// `extract` Edge Function to run it right away. The first document and
  /// the "Aggiorna" tap never wait for the nightly batch.
  Future<Extraction> startExtraction(String documentId) async {
    try {
      final dynamic queued = await SupabaseConfig.rpc('start_extraction',
          params: <String, dynamic>{'p_document_id': documentId});
      final String extractionId = queued.toString();
      AppLogger.event('extraction_started');

      // Fire and forget: the UI follows the state through realtime.
      unawaitedInvoke(extractionId);

      final Extraction? created = await fetchExtraction(extractionId);
      if (created == null) throw AppFailure.generic;
      return created;
    } catch (e) {
      throw _mapError(e, 'analysis.startExtraction');
    }
  }

  /// Invokes `extract` without blocking the caller. Errors are logged, the
  /// row stays `queued` and the nightly batch will pick it up.
  void unawaitedInvoke(String extractionId) {
    _db.functions
        .invoke('extract',
            body: <String, dynamic>{'extraction_id': extractionId})
        .then((FunctionResponse _) => AppLogger.event('extraction_invoked'))
        .catchError((Object e) {
      AppLogger.error('analysis.invokeExtract', e);
      return const FunctionResponse(status: 500);
    });
  }

  /// Runs the extraction and waits for the result. Used by "Riprova".
  Future<Extraction?> runExtraction(String extractionId, {bool force = false}) async {
    try {
      await _db.functions.invoke('extract',
          body: <String, dynamic>{
            'extraction_id': extractionId,
            'force': force,
          });
      return fetchExtraction(extractionId);
    } catch (e) {
      throw _mapError(e, 'analysis.runExtraction');
    }
  }

  /// New attempt on a failed document: a new row in `extractions`.
  Future<Extraction> retry(String documentId) => startExtraction(documentId);

  Future<Extraction?> fetchExtraction(String extractionId) async {
    try {
      final Map<String, dynamic>? row = await _db
          .from(_extractions)
          .select()
          .eq('id', extractionId)
          .maybeSingle();
      return row == null ? null : Extraction.fromJson(row);
    } catch (e) {
      throw _mapError(e, 'analysis.fetchExtraction');
    }
  }

  /// Most recent extraction of a document, or null if it was never read.
  Future<Extraction?> latestForDocument(String documentId) async {
    try {
      final Map<String, dynamic>? row = await _db
          .from(_extractions)
          .select()
          .eq('document_id', documentId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : Extraction.fromJson(row);
    } catch (e) {
      throw _mapError(e, 'analysis.latestForDocument');
    }
  }

  /// Every attempt on a document, newest first.
  Future<List<Extraction>> historyForDocument(String documentId) async {
    try {
      final List<Map<String, dynamic>> rows = await _db
          .from(_extractions)
          .select()
          .eq('document_id', documentId)
          .order('created_at', ascending: false);
      return rows
          .map((Map<String, dynamic> r) => Extraction.fromJson(r))
          .toList(growable: false);
    } catch (e) {
      throw _mapError(e, 'analysis.historyForDocument');
    }
  }

  /// Realtime state of one extraction, so the screen follows the pipeline
  /// without polling. RLS keeps the stream to the rows the user may see.
  Stream<Extraction?> watchExtraction(String extractionId) => _db
      .from(_extractions)
      .stream(primaryKey: <String>['id'])
      .eq('id', extractionId)
      .map((List<Map<String, dynamic>> rows) =>
          rows.isEmpty ? null : Extraction.fromJson(rows.first));

  /// Realtime state of every extraction of the subject, newest first.
  Stream<List<Extraction>> watchSubjectExtractions({String? subjectId}) {
    final String subject = subjectId ?? _uid;
    return _db
        .from(_extractions)
        .stream(primaryKey: <String>['id'])
        .eq('subject_id', subject)
        .order('created_at', ascending: false)
        .limit(50)
        .map((List<Map<String, dynamic>> rows) => rows
            .map((Map<String, dynamic> r) => Extraction.fromJson(r))
            .toList(growable: false));
  }

  // -------------------------------------------------------------------------
  // Observations
  // -------------------------------------------------------------------------

  /// Current values of a document (superseded rows excluded).
  Future<List<Observation>> observationsForDocument(String documentId) async {
    try {
      final List<Map<String, dynamic>> rows = await _db
          .from(_observations)
          .select()
          .eq('document_id', documentId)
          .isFilter('superseded_at', null)
          .order('needs_review', ascending: false)
          .order('display_name');
      return rows
          .map((Map<String, dynamic> r) => Observation.fromJson(r))
          .toList(growable: false);
    } catch (e) {
      throw _mapError(e, 'analysis.observationsForDocument');
    }
  }

  /// Every value of one biomarker, oldest first: this is the history that
  /// M4 draws. Superseded rows are excluded but never deleted.
  Future<List<Observation>> historyForCode(
    String code, {
    String? subjectId,
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) async {
    final String subject = subjectId ?? _uid;
    try {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _db
          .from(_observations)
          .select()
          .eq('subject_id', subject)
          .eq('code', code)
          .isFilter('superseded_at', null);
      if (from != null) {
        query = query.gte('effective_at', from.toUtc().toIso8601String());
      }
      if (to != null) {
        query = query.lte('effective_at', to.toUtc().toIso8601String());
      }
      final List<Map<String, dynamic>> rows =
          await query.order('effective_at').limit(limit);
      return rows
          .map((Map<String, dynamic> r) => Observation.fromJson(r))
          .toList(growable: false);
    } catch (e) {
      throw _mapError(e, 'analysis.historyForCode');
    }
  }

  /// Values waiting for the user confirmation (step 5 of the pipeline).
  Future<List<Observation>> pendingReview({
    String? subjectId,
    String? documentId,
    int limit = 100,
  }) async {
    final String subject = subjectId ?? _uid;
    try {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _db
          .from(_observations)
          .select()
          .eq('subject_id', subject)
          .eq('needs_review', true)
          .isFilter('superseded_at', null);
      if (documentId != null) query = query.eq('document_id', documentId);
      final List<Map<String, dynamic>> rows =
          await query.order('created_at', ascending: false).limit(limit);
      return rows
          .map((Map<String, dynamic> r) => Observation.fromJson(r))
          .toList(growable: false);
    } catch (e) {
      throw _mapError(e, 'analysis.pendingReview');
    }
  }

  /// Latest value of every biomarker the subject has, newest first.
  Future<List<Observation>> latestPerCode({
    String? subjectId,
    int limit = 300,
  }) async {
    final String subject = subjectId ?? _uid;
    try {
      final List<Map<String, dynamic>> rows = await _db
          .from(_observations)
          .select()
          .eq('subject_id', subject)
          .isFilter('superseded_at', null)
          .order('effective_at', ascending: false)
          .limit(limit);
      final Map<String, Observation> latest = <String, Observation>{};
      for (final Map<String, dynamic> r in rows) {
        final Observation o = Observation.fromJson(r);
        final Observation? kept = latest[o.code];
        if (kept == null || o.effectiveAt.isAfter(kept.effectiveAt)) {
          latest[o.code] = o;
        }
      }
      return latest.values.toList(growable: false)
        ..sort((Observation a, Observation b) =>
            b.effectiveAt.compareTo(a.effectiveAt));
    } catch (e) {
      throw _mapError(e, 'analysis.latestPerCode');
    }
  }

  /// Confirms or corrects a value. The row is never updated: Postgres
  /// writes a new observation and marks the previous one superseded.
  /// Returns the id of the new row.
  Future<String> confirmObservation(
    String observationId, {
    double? valueNum,
    String? unit,
    String? valueText,
    DateTime? effectiveAt,
    String outcome = 'confirmed',
  }) async {
    try {
      final dynamic newId = await SupabaseConfig.rpc('confirm_observation',
          params: <String, dynamic>{
            'p_observation_id': observationId,
            'p_value_num': valueNum,
            'p_unit': unit,
            'p_value_text': valueText,
            'p_effective_at': effectiveAt?.toUtc().toIso8601String(),
             'p_outcome': outcome,
          });
      AppLogger.event(valueNum == null && valueText == null
          ? 'observation_confirmed'
          : 'observation_corrected');
      return newId.toString();
    } catch (e) {
      throw _mapError(e, 'analysis.confirmObservation');
    }
  }

  /// Discards a review candidate through the same append-only RPC.
  Future<String> discardObservation(String observationId) => confirmObservation(observationId, outcome: 'discarded');

  /// Realtime values of a document, so confirmations and new readings show
  /// up without a manual refresh.
  Stream<List<Observation>> watchDocumentObservations(String documentId) => _db
      .from(_observations)
      .stream(primaryKey: <String>['id'])
      .eq('document_id', documentId)
      .map((List<Map<String, dynamic>> rows) => rows
          .map((Map<String, dynamic> r) => Observation.fromJson(r))
          .where((Observation o) => o.isCurrent)
          .toList(growable: false));

  // -------------------------------------------------------------------------
  // Plan usage
  // -------------------------------------------------------------------------

  /// `analysis_usage()`: readings consumed this month and plan limit.
  /// The count comes from Postgres under RLS, never from a client filter.
  Future<AnalysisUsage> analysisUsage() async {
    try {
      final dynamic data = await SupabaseConfig.rpc('analysis_usage');
      final Map<String, dynamic>? row = data is List
          ? (data.isEmpty ? null : Map<String, dynamic>.from(data.first as Map))
          : (data is Map ? Map<String, dynamic>.from(data) : null);
      if (row == null) return const AnalysisUsage(used: 0, max: 0);
      return AnalysisUsage(
        used: (row['used'] as num?)?.toInt() ?? 0,
        max: (row['max'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw _mapError(e, 'analysis.analysisUsage');
    }
  }

  // -------------------------------------------------------------------------
  AppFailure _mapError(Object error, String where) {
    if (error is AppFailure) return error;
    if (error is PostgrestException) {
      final String message = error.message.toLowerCase();
      if (message.contains('document_not_ready')) {
        AppLogger.error(where, 'document_not_ready');
        return AnalysisFailures.documentNotReady;
      }
      if (message.contains('observation_superseded')) {
        AppLogger.error(where, 'observation_superseded');
        return AnalysisFailures.observationSuperseded;
      }
      if (message.contains('observations_append_only')) {
        AppLogger.error(where, 'observations_append_only');
        return AnalysisFailures.appendOnly;
      }
    }
    return AppFailure.from(error, where: where);
  }
}

/// Result of `analysis_usage()`: readings this month and plan limit.
class AnalysisUsage {
  const AnalysisUsage({required this.used, required this.max});

  final int used;
  final int max;

  bool get isLimitReached => max > 0 && used >= max;
  int get remaining => max <= 0 ? 0 : (max - used).clamp(0, max);
}

/// Failures specific to the extraction engine.
class AnalysisFailures {
  const AnalysisFailures._();

  static const AppFailure documentNotReady = AppFailure(
    'Il documento è ancora in caricamento. Riprova tra poco.',
    'The document is still uploading. Please try again shortly.',
    code: 'document_not_ready',
  );

  static const AppFailure observationSuperseded = AppFailure(
    'Questo valore è già stato corretto.',
    'This value has already been corrected.',
    code: 'observation_superseded',
  );

  static const AppFailure appendOnly = AppFailure(
    'I valori non si modificano: ogni correzione crea una nuova riga.',
    'Values are never overwritten: every correction creates a new row.',
    code: 'observations_append_only',
  );

  static const AppFailure extractionFailed = AppFailure(
    'Non siamo riusciti a leggere questo documento. Riprova.',
    'We could not read this document. Please try again.',
    code: 'extraction_failed',
  );

  static const AppFailure limitReached = AppFailure(
    'Hai raggiunto il limite di analisi del mese.',
    'You reached this month\'s analysis limit.',
    code: 'analysis_limit_reached',
  );
}
