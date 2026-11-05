import 'package:medical24/features/doctor/data/doctor_models.dart';
import 'package:medical24/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorRepository {
  const DoctorRepository(this.subjectId);
  final String? subjectId;
  SupabaseClient get _db => SupabaseConfig.client;
  String get _subject => subjectId ?? (throw const DoctorException('not_allowed'));

  Future<List<DoctorShareLink>> links() async {
    final dynamic value = await _db.rpc('share_links_for_subject', params: <String, dynamic>{'p_subject': _subject});
    return (value as List? ?? const <dynamic>[]).whereType<Map>().map((row) => DoctorShareLink.fromJson(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  Future<DoctorShareLink> createLink({required String pin, required DoctorShareScope scope, required int expiresDays, required int maxOpens}) async {
    try {
      final dynamic value = await _db.rpc('share_link_create', params: <String, dynamic>{'p_subject': _subject, 'p_pin': pin, 'p_scope': scope.toJson(), 'p_expires_in': '$expiresDays days', 'p_max_opens': maxOpens});
      return DoctorShareLink.fromJson(<String, dynamic>{...Map<String, dynamic>.from(value as Map), 'opens_count': 0, 'status': 'active', 'opens': const <dynamic>[]});
    } on PostgrestException catch (error) {
      throw DoctorException(_knownCode(error.message));
    }
  }

  Future<void> revokeLink(String id) => _db.rpc('share_link_revoke', params: <String, dynamic>{'p_id': id});

  Future<DoctorDossier?> latestDossier() async {
    final dynamic value = await _db.rpc('dossier_latest', params: <String, dynamic>{'p_subject': _subject});
    if (value is! Map) return null;
    final Map<String, dynamic> row = Map<String, dynamic>.from(value);
    final dynamic rules = await _db.from('dossier_snapshots').select('rule_versions').eq('id', row['id']).maybeSingle();
    row['rule_versions'] = rules is Map ? rules['rule_versions'] : const <String, dynamic>{};
    return DoctorDossier.fromJson(row);
  }

  Future<String> buildDossier() async => (await _db.rpc('dossier_build', params: <String, dynamic>{'p_subject': _subject, 'p_scope': <String, dynamic>{'all': true}, 'p_share_link_id': null})).toString();

  Future<Uri> pdf(String snapshotId, String lang) async {
    final FunctionResponse response = await _db.functions.invoke('dossier-pdf', body: <String, dynamic>{'snapshot_id': snapshotId, 'lang': lang});
    final Map<String, dynamic> data = Map<String, dynamic>.from(response.data as Map);
    return Uri.parse(data['url'].toString());
  }

  Future<List<DoctorQuestion>> questions() async {
    final List<dynamic> rows = await _db.from('questions').select().eq('subject_id', _subject).order('created_at', ascending: false);
    return rows.map((row) => DoctorQuestion.fromJson(Map<String, dynamic>.from(row as Map))).toList(growable: false);
  }

  Future<String> createQuestion({required String title, required String body, String? shareLinkId, String? doctorEmail}) => _rpcId('question_create', <String, dynamic>{'p_subject': _subject, 'p_title': title, 'p_body': body, 'p_share_link_id': shareLinkId, 'p_doctor_email': doctorEmail});
  Future<void> updateQuestion(String id, String title, String body) => _rpc('question_update', <String, dynamic>{'p_id': id, 'p_title': title, 'p_body': body});
  Future<void> sendQuestion(String id) => _rpc('question_send', <String, dynamic>{'p_id': id});
  Future<void> recordAnswer(String id, String answer) => _rpc('question_record_answer', <String, dynamic>{'p_id': id, 'p_answer': answer});
  Future<void> closeQuestion(String id) => _rpc('question_close', <String, dynamic>{'p_id': id});
  Future<void> deleteQuestion(String id) => _rpc('question_delete', <String, dynamic>{'p_id': id});

  Future<EmergencyCard?> emergencyCard() async {
    final Map<String, dynamic>? row = await _db.from('emergency_cards').select().eq('subject_id', _subject).maybeSingle();
    return row == null ? null : EmergencyCard.fromJson(row);
  }

  Future<EmergencyCard> saveEmergencyCard(Map<String, dynamic> changes) async {
    try {
      final dynamic value = await _db.rpc('emergency_card_upsert', params: <String, dynamic>{'p_subject': _subject, 'p_payload': changes});
      return EmergencyCard.fromJson(Map<String, dynamic>.from(value as Map));
    } on PostgrestException catch (error) { throw DoctorException(_knownCode(error.message, code: error.code)); }
  }

  Future<String> regenerateEmergencyToken() => _rpcId('emergency_card_regenerate_token', <String, dynamic>{'p_subject': _subject});

  Future<void> _rpc(String name, Map<String, dynamic> params) async {
    try { await _db.rpc(name, params: params); } on PostgrestException catch (error) { throw DoctorException(_knownCode(error.message, code: error.code)); }
  }

  Future<String> _rpcId(String name, Map<String, dynamic> params) async {
    try { return (await _db.rpc(name, params: params)).toString(); } on PostgrestException catch (error) { throw DoctorException(_knownCode(error.message, code: error.code)); }
  }

  static String _knownCode(String message, {String? code}) {
    if (code == '23514') return '23514';
    for (final String known in const <String>['weak_pin', 'too_many_links', 'invalid_scope', 'daily_limit', 'not_editable', 'not_sendable', 'not_answerable', 'invalid_share_link', 'unknown_key']) if (message.contains(known)) return known;
    return 'unknown';
  }
}

class DoctorException implements Exception {
  const DoctorException(this.code);
  final String code;
}