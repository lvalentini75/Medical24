import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/features/health/prevention/data/prevention_models.dart';
import 'package:medical24/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class PreventionRepository {
  Future<PreventionSnapshot> load({bool refresh = true});
  Future<void> saveAnswers(Map<String, dynamic> answers, String version);
  Future<void> completeRecommendation(String id, {String? documentId});
  Future<void> dismissRecommendation(String id, {String? reason});
  Future<void> reopenRecommendation(String id);
}

class SupabasePreventionRepository implements PreventionRepository {
  const SupabasePreventionRepository();
  SupabaseClient get _db => SupabaseConfig.client;
  String get _subject => SupabaseConfig.currentUserId ?? (throw AppFailure.unauthorized);

  @override
  Future<PreventionSnapshot> load({bool refresh = true}) async {
    if (refresh) await _db.rpc('refresh_recommendations', params: <String, dynamic>{'p_subject': _subject});
    final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
      _db.from('recommendations').select().eq('subject_id', _subject).order('due_at'),
      _db.from('latest_risk_scores').select().eq('subject_id', _subject),
      _db.from('risk_scores').select().eq('subject_id', _subject).order('computed_at'),
      _db.from('questionnaires').select('id,definition,version').eq('id', 'risk_baseline').maybeSingle(),
      _db.from('questionnaire_answers').select('version,answers,submitted_at').eq('subject_id', _subject).eq('questionnaire_id', 'risk_baseline').order('submitted_at', ascending: false).limit(1).maybeSingle(),
      _db.from('biomarker_series').select('canonical_value,effective_at').eq('subject_id', _subject).eq('code', '29463-7').order('effective_at', ascending: false).limit(1).maybeSingle(),
      _db.from('biomarker_catalog').select('code,name_it,name_en'),
    ]);
    final Map<String, dynamic> questionnaireRow = result[3] is Map ? Map<String, dynamic>.from(result[3] as Map) : <String, dynamic>{};
    final Map<String, dynamic> definition = Map<String, dynamic>.from(questionnaireRow['definition'] as Map? ?? const <String, dynamic>{});
    final Map<String, dynamic>? answer = result[4] is Map ? Map<String, dynamic>.from(result[4] as Map) : null;
    final Map<String, Map<String, String>> names = <String, Map<String, String>>{for (final dynamic row in result[6] as List) row['code'].toString(): <String, String>{'it': (row['name_it'] ?? row['code']).toString(), 'en': (row['name_en'] ?? row['code']).toString()}};
    final Map<String, dynamic>? weight = result[5] is Map ? Map<String, dynamic>.from(result[5] as Map) : null;
    return PreventionSnapshot(recommendations: (result[0] as List).map((dynamic row) => PreventionRecommendation.fromJson(Map<String, dynamic>.from(row as Map))).toList(), risks: (result[1] as List).map((dynamic row) => RiskScore.fromJson(Map<String, dynamic>.from(row as Map))).toList(), riskHistory: (result[2] as List).map((dynamic row) => RiskScore.fromJson(Map<String, dynamic>.from(row as Map))).toList(), questionnaire: QuestionnaireState(version: (questionnaireRow['version'] ?? answer?['version'] ?? '0.1-draft').toString(), questions: (definition['questions'] as List? ?? const <dynamic>[]).map((dynamic value) => value is Map ? (value['key'] ?? value['id']).toString() : value.toString()).toList(), answers: Map<String, dynamic>.from(answer?['answers'] as Map? ?? const <String, dynamic>{}), submittedAt: answer?['submitted_at'] == null ? null : DateTime.tryParse(answer!['submitted_at'].toString())?.toLocal(), latestWeightKg: (weight?['canonical_value'] as num?)?.toDouble(), latestWeightAt: weight?['effective_at'] == null ? null : DateTime.tryParse(weight!['effective_at'].toString())?.toLocal()), biomarkerNames: names);
  }

  @override
  Future<void> saveAnswers(Map<String, dynamic> answers, String version) async {
    await _db.from('questionnaire_answers').insert(<String, dynamic>{'subject_id': _subject, 'questionnaire_id': 'risk_baseline', 'version': version, 'answers': answers});
    await _db.rpc('refresh_recommendations', params: <String, dynamic>{'p_subject': _subject});
  }
  @override
  Future<void> completeRecommendation(String id, {String? documentId}) => _db.rpc('complete_recommendation', params: <String, dynamic>{'p_id': id, 'p_document': documentId});
  @override
  Future<void> dismissRecommendation(String id, {String? reason}) => _db.rpc('dismiss_recommendation', params: <String, dynamic>{'p_id': id, 'p_reason': reason});
  @override
  Future<void> reopenRecommendation(String id) => _db.rpc('reopen_recommendation', params: <String, dynamic>{'p_id': id});
}