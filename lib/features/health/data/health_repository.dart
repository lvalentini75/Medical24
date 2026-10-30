import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contract kept injectable so widget tests can use data that never reaches production UI.
abstract class HealthRepository {
  Future<List<BiomarkerSummary>> catalog();
  Future<List<ManualBiomarker>> manualCatalog();
  Future<BiomarkerHistoryData> history(String code, {DateTime? from, DateTime? to});
  Future<void> setWatch(BiomarkerSummary biomarker, {bool? favorite, bool? tracked});
  Future<void> insertManualValues(List<ManualObservationInput> values, DateTime effectiveAt);
  Future<List<Map<String, dynamic>>> exportRows();
}

class ManualValueException implements Exception {
  const ManualValueException(this.code);
  final String code;
}

/// Supabase implementation. Authorization is always enforced by backend RLS.
class SupabaseHealthRepository implements HealthRepository {
  const SupabaseHealthRepository();

  SupabaseClient get _db => SupabaseConfig.client;
  String get _subjectId => SupabaseConfig.currentUserId ?? (throw AppFailure.unauthorized);

  @override
  Future<List<BiomarkerSummary>> catalog() async {
    final dynamic data = await SupabaseConfig.rpc('biomarker_catalog_for_subject', params: <String, dynamic>{'p_subject': _subjectId});
    return (data as List? ?? const <dynamic>[]).whereType<Map>().map((Map row) => BiomarkerSummary.fromJson(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  @override
  Future<List<ManualBiomarker>> manualCatalog() async {
    const List<String> codes = <String>['8480-6', '8462-4', '29463-7', '2345-7', '8867-4', '8310-5', '59408-5'];
    final List<Map<String, dynamic>> data = await _db.from('biomarker_catalog').select('code,name_it,name_en,unit_canonical,unit_alternatives,plausible_min,plausible_max').inFilter('code', codes);
    return data.map(ManualBiomarker.fromJson).toList(growable: false);
  }

  @override
  Future<void> insertManualValues(List<ManualObservationInput> values, DateTime effectiveAt) async {
    try {
      await _db.from('observations').insert(values.map((ManualObservationInput value) => <String, dynamic>{'subject_id': _subjectId, 'code': value.code, 'value_raw': value.value, 'unit_raw': value.unit, 'origin': 'manual', 'effective_at': effectiveAt.toUtc().toIso8601String()}).toList(growable: false));
    } on PostgrestException catch (error) {
      const List<String> known = <String>['manual_value_not_plausible', 'manual_unit_not_supported', 'manual_code_not_allowed', 'not_allowed'];
      final String code = known.firstWhere((String value) => error.message.contains(value), orElse: () => 'unknown');
      throw ManualValueException(code);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> exportRows() async {
    final dynamic data = await SupabaseConfig.rpc('observations_export', params: <String, dynamic>{'p_subject': _subjectId});
    return (data as List? ?? const <dynamic>[]).whereType<Map>().map((Map row) => Map<String, dynamic>.from(row)).toList(growable: false);
  }

  @override
  Future<BiomarkerHistoryData> history(String code, {DateTime? from, DateTime? to}) async {
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _db.from('biomarker_series').select().eq('subject_id', _subjectId).eq('code', code);
    if (from != null) query = query.gte('effective_at', from.toUtc().toIso8601String());
    if (to != null) query = query.lte('effective_at', to.toUtc().toIso8601String());
    final Future<List<Map<String, dynamic>>> pointsFuture = query.order('effective_at');
    final Future<dynamic> statsFuture = SupabaseConfig.rpc('biomarker_stats', params: <String, dynamic>{'p_subject': _subjectId, 'p_code': code, 'p_from': from?.toUtc().toIso8601String(), 'p_to': to?.toUtc().toIso8601String()});
    final Future<dynamic> episodesFuture = SupabaseConfig.rpc('biomarker_episodes', params: <String, dynamic>{'p_subject': _subjectId, 'p_code': code});
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[pointsFuture, statsFuture, episodesFuture]);
    final List<BiomarkerPoint> points = (results[0] as List).whereType<Map>().map((Map row) => BiomarkerPoint.fromJson(Map<String, dynamic>.from(row))).toList(growable: false);
    final Map<String, dynamic> statsRow = _firstRow(results[1]);
    final List<BiomarkerEpisode> episodes = (results[2] as List? ?? const <dynamic>[]).whereType<Map>().map((Map row) => BiomarkerEpisode.fromJson(Map<String, dynamic>.from(row))).toList(growable: false);
    return BiomarkerHistoryData(points: points, stats: BiomarkerStats.fromJson(statsRow), episodes: episodes);
  }

  @override
  Future<void> setWatch(BiomarkerSummary biomarker, {bool? favorite, bool? tracked}) async {
    final bool nextFavorite = favorite ?? biomarker.favorite;
    final bool nextTracked = tracked ?? biomarker.tracked;
    if (!nextFavorite && !nextTracked) {
      await _db.from('biomarker_watch').delete().eq('subject_id', _subjectId).eq('code', biomarker.code);
      return;
    }
    await _db.from('biomarker_watch').upsert(<String, dynamic>{'subject_id': _subjectId, 'code': biomarker.code, 'favorite': nextFavorite, 'tracked': nextTracked}, onConflict: 'subject_id,code');
  }

  Map<String, dynamic> _firstRow(dynamic data) {
    if (data is List && data.isNotEmpty && data.first is Map) return Map<String, dynamic>.from(data.first as Map);
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}