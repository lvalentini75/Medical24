import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/features/health/body/data/body_models.dart';
import 'package:medical24/supabase/supabase_config.dart';

abstract class BodyRepository {
  Future<List<OrganOverview>> overview();
  Future<List<OrganBiomarker>> biomarkers(String organ);
  Future<List<OrganHistoryEntry>> history(String organ);
  Future<OrganComparison> comparison(String organ);
  Future<List<OrganEpisode>> episodes(String organ);
  Future<OrganRuleVersion?> activeRule();
  Future<int> compute();
}

class SupabaseBodyRepository implements BodyRepository {
  const SupabaseBodyRepository();
  String get _subject => SupabaseConfig.currentUserId ?? (throw AppFailure.unauthorized);
  Future<dynamic> _organRpc(String name, String organ) => SupabaseConfig.rpc(name, params: <String, dynamic>{'p_subject': _subject, 'p_organ': organ});
  List<Map<String, dynamic>> _rows(dynamic data) => (data as List? ?? const <dynamic>[]).whereType<Map>().map((Map row) => Map<String, dynamic>.from(row)).toList(growable: false);

  @override
  Future<List<OrganOverview>> overview() async => _rows(await SupabaseConfig.rpc('organ_overview', params: <String, dynamic>{'p_subject': _subject})).map(OrganOverview.fromJson).toList(growable: false);
  @override
  Future<List<OrganBiomarker>> biomarkers(String organ) async => _rows(await _organRpc('organ_biomarkers', organ)).map(OrganBiomarker.fromJson).toList(growable: false);
  @override
  Future<List<OrganHistoryEntry>> history(String organ) async => _rows(await _organRpc('organ_history', organ)).map(OrganHistoryEntry.fromJson).toList(growable: false);
  @override
  Future<OrganComparison> comparison(String organ) async { final List<Map<String, dynamic>> rows = _rows(await _organRpc('organ_comparison', organ)); return OrganComparison.fromJson(rows.firstOrNull ?? const <String, dynamic>{}); }
  @override
  Future<List<OrganEpisode>> episodes(String organ) async => _rows(await _organRpc('organ_episodes', organ)).map(OrganEpisode.fromJson).toList(growable: false);
  @override
  Future<OrganRuleVersion?> activeRule() async { final List<Map<String, dynamic>> rows = await SupabaseConfig.client.from('rule_versions').select('version,notes').eq('type', 'organ_state').eq('status', 'active').limit(1); return rows.isEmpty ? null : OrganRuleVersion.fromJson(rows.first); }
  @override
  Future<int> compute() async => (await SupabaseConfig.rpc('compute_organ_states', params: <String, dynamic>{'p_subject': _subject}) as num?)?.toInt() ?? 0;
}