import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/features/health/data/alert_models.dart';
import 'package:medical24/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AlertsRepository {
  Future<List<HealthAlert>> list();
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
}

class SupabaseAlertsRepository implements AlertsRepository {
  const SupabaseAlertsRepository();
  SupabaseClient get _db => SupabaseConfig.client;
  String get _uid => SupabaseConfig.currentUserId ?? (throw AppFailure.unauthorized);

  @override
  Future<List<HealthAlert>> list() async {
    final List<Map<String, dynamic>> alerts = await _db.from('alerts').select('id,type,code,level,message_key,created_at,read_at').eq('subject_id', _uid).order('created_at', ascending: false);
    final List<String> codes = alerts.map((Map<String, dynamic> row) => row['code']?.toString() ?? '').where((String code) => code.isNotEmpty).toSet().toList();
    final Map<String, Map<String, dynamic>> names = <String, Map<String, dynamic>>{};
    if (codes.isNotEmpty) {
      final List<Map<String, dynamic>> catalog = await _db.from('biomarker_catalog').select('code,name_it,name_en').inFilter('code', codes);
      for (final Map<String, dynamic> row in catalog) names[row['code'].toString()] = row;
    }
    return alerts.map((Map<String, dynamic> row) => HealthAlert.fromJson(<String, dynamic>{...row, ...?names[row['code']?.toString()]})).toList(growable: false);
  }

  @override
  Future<int> unreadCount() async => (await _db.from('alerts').select('id').eq('subject_id', _uid).isFilter('read_at', null)).length;
  @override
  Future<void> markRead(String id) => _db.from('alerts').update(<String, dynamic>{'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id).eq('subject_id', _uid);
  @override
  Future<void> markAllRead() => _db.from('alerts').update(<String, dynamic>{'read_at': DateTime.now().toUtc().toIso8601String()}).eq('subject_id', _uid).isFilter('read_at', null);
}