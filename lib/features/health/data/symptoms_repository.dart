import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/features/health/data/symptom_models.dart';
import 'package:medical24/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SymptomsRepository {
  Future<List<SymptomEntry>> list();
  Future<SymptomEntry?> get(String id);
  Future<void> create(SymptomInput input);
  Future<void> update(String id, SymptomInput input);
  Future<void> delete(String id);
}

class SupabaseSymptomsRepository implements SymptomsRepository {
  const SupabaseSymptomsRepository();
  SupabaseClient get _db => SupabaseConfig.client;
  String get _uid => SupabaseConfig.currentUserId ?? (throw AppFailure.unauthorized);

  @override
  Future<List<SymptomEntry>> list() async {
    final List<Map<String, dynamic>> rows = await _db.from('symptoms').select().eq('subject_id', _uid).isFilter('deleted_at', null).order('occurred_at', ascending: false);
    return rows.map(SymptomEntry.fromJson).toList(growable: false);
  }

  @override
  Future<SymptomEntry?> get(String id) async {
    final Map<String, dynamic>? row = await _db.from('symptoms').select().eq('id', id).eq('subject_id', _uid).isFilter('deleted_at', null).maybeSingle();
    return row == null ? null : SymptomEntry.fromJson(row);
  }

  Map<String, dynamic> _values(SymptomInput input) => <String, dynamic>{'code': input.code, 'free_text': input.freeText, 'severity': input.severity, 'notes': input.notes, 'occurred_at': input.occurredAt.toUtc().toIso8601String()};

  @override
  Future<void> create(SymptomInput input) => _db.from('symptoms').insert(<String, dynamic>{..._values(input), 'subject_id': _uid, 'created_by': _uid});
  @override
  Future<void> update(String id, SymptomInput input) => _db.from('symptoms').update(_values(input)).eq('id', id).eq('subject_id', _uid);
  @override
  Future<void> delete(String id) => SupabaseConfig.rpc('soft_delete_symptom', params: <String, dynamic>{'p_symptom_id': id});
}