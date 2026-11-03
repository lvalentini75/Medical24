import 'package:medical24/features/admin/data/admin_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AdminPostgrestClient {
  Future<dynamic> rpc(String name, {Map<String, dynamic>? params});
  Future<List<Map<String, dynamic>>> select(String table, {String columns = '*', Map<String, dynamic> equals = const <String, dynamic>{}, Map<String, List<String>> inFilters = const <String, List<String>>{}, String? searchColumn, String? searchPattern, String? orderBy, bool ascending = true, int? limit, int? rangeFrom, int? rangeTo});
  Future<dynamic> invoke(String function, Map<String, dynamic> body);
}

class SupabaseAdminPostgrestClient implements AdminPostgrestClient {
  SupabaseAdminPostgrestClient(this.client);
  final SupabaseClient client;
  @override Future<dynamic> rpc(String name, {Map<String, dynamic>? params}) => client.rpc(name, params: params);
  @override Future<dynamic> invoke(String function, Map<String, dynamic> body) async => (await client.functions.invoke(function, body: body)).data;
  @override Future<List<Map<String, dynamic>>> select(String table, {String columns = '*', Map<String, dynamic> equals = const <String, dynamic>{}, Map<String, List<String>> inFilters = const <String, List<String>>{}, String? searchColumn, String? searchPattern, String? orderBy, bool ascending = true, int? limit, int? rangeFrom, int? rangeTo}) async {
    dynamic query = client.from(table).select(columns);
    for (final entry in equals.entries) query = query.eq(entry.key, entry.value);
    for (final entry in inFilters.entries) query = query.inFilter(entry.key, entry.value);
    if (searchColumn != null && searchPattern != null) query = query.ilike(searchColumn, searchPattern);
    if (orderBy != null) query = query.order(orderBy, ascending: ascending);
    if (rangeFrom != null && rangeTo != null) query = query.range(rangeFrom, rangeTo);
    if (limit != null) query = query.limit(limit);
    final List<dynamic> rows = await query as List<dynamic>;
    return rows.map((dynamic row) => Map<String, dynamic>.from(row as Map)).toList();
  }
}

class AdminRepository {
  AdminRepository({SupabaseClient? client, AdminPostgrestClient? postgrest}) : _client = postgrest ?? SupabaseAdminPostgrestClient(client ?? Supabase.instance.client);
  final AdminPostgrestClient _client;

  Future<bool> isAdmin() async { final id = _client is SupabaseAdminPostgrestClient ? (_client as SupabaseAdminPostgrestClient).client.auth.currentUser?.id : null; if (id == null) return false; final rows = await _client.select('user_roles', columns: 'role', equals: <String, dynamic>{'user_id': id}); return rows.any((row) => row['role'] == 'admin'); }
  Future<AdminOverviewData> overview() async => AdminOverviewData.fromJson(Map<String, dynamic>.from(await _client.rpc('admin_overview') as Map));
  Future<List<AdminAiTask>> tasks() async => _rpcRows('admin_ai_tasks').then((rows) => rows.map(AdminAiTask.fromJson).toList());
  Future<List<AdminAiModel>> models() async => (await _client.select('ai_models', orderBy: 'id')).map(AdminAiModel.fromJson).toList();
  Future<List<AdminSetting>> settings() async => (await _client.select('platform_settings', orderBy: 'key')).map(AdminSetting.fromJson).toList();
  Future<List<AdminSetting>> settingHistory(String key) async => (await _client.select('platform_settings_history', equals: <String, dynamic>{'key': key}, orderBy: 'version', ascending: false)).map(AdminSetting.fromJson).toList();
  Future<void> setTask(String id, Map<String, dynamic> patch) async => _client.rpc('ai_task_set', params: <String, dynamic>{'p_task': id, 'p_patch': patch});
  Future<void> setModel(String id, Map<String, dynamic> patch) async => _client.rpc('ai_model_set', params: <String, dynamic>{'p_id': id, 'p_patch': patch});
  Future<void> setSetting(AdminSetting setting, dynamic value) async => _client.rpc('platform_setting_set', params: <String, dynamic>{'p_key': setting.key, 'p_value': value, 'p_description': setting.description});
  Future<List<AdminPrompt>> prompts(String task) async => _rpcRows('admin_prompts', <String, dynamic>{'p_task': task}).then((rows) => rows.map(AdminPrompt.fromJson).toList());
  Future<void> approvePrompt(String id) async => _client.rpc('ai_prompt_approve', params: <String, dynamic>{'p_id': id});
  Future<void> activatePrompt(String id) async => _client.rpc('ai_prompt_activate', params: <String, dynamic>{'p_id': id});
  Future<String> rollbackPrompt(String task) async => '${await _client.rpc('ai_prompt_rollback', params: <String, dynamic>{'p_task': task})}';
  Future<String> createPrompt({required String task, required String systemPrompt, required String userTemplate, required Map<String, dynamic> toolSchema, String? notes}) async => '${await _client.rpc('ai_prompt_create', params: <String, dynamic>{'p_task': task, 'p_system_prompt': systemPrompt, 'p_tool_schema': toolSchema, 'p_user_template': userTemplate, 'p_notes': notes})}';
  Future<List<AdminDryRunCase>> testPrompt(String id) async { final dynamic data = await _client.invoke('explain', <String, dynamic>{'dry_run': true, 'prompt_id': id}); return _maps((data as Map)['cases']).map(AdminDryRunCase.fromJson).toList(); }

  Future<List<AdminUsageRow>> usage(DateTime from, DateTime to, String? task) async => _rpcRows('admin_usage', <String, dynamic>{..._range(from, to), 'p_task': task}).then((rows) => rows.map(AdminUsageRow.fromJson).toList());
  Future<List<AdminAiCall>> aiCalls(DateTime from, DateTime to, {String? task, String? status, int offset = 0}) async => _rpcRows('admin_ai_calls', <String, dynamic>{..._range(from, to), 'p_task': task, 'p_status': status, 'p_limit': 50, 'p_offset': offset}).then((rows) => rows.map(AdminAiCall.fromJson).toList());
  Future<List<AdminEvent>> events(DateTime from, DateTime to, {String? type, int offset = 0}) async => _rpcRows('admin_events', <String, dynamic>{..._range(from, to), 'p_kind': type, 'p_limit': 100, 'p_offset': offset}).then((rows) => rows.map(AdminEvent.fromJson).toList());
  Future<List<AdminAuditEntry>> audit(DateTime from, DateTime to, {String? action, String? actor, int offset = 0}) async => _rpcRows('admin_audit', <String, dynamic>{..._range(from, to), 'p_action': action, 'p_actor': actor, 'p_limit': 100, 'p_offset': offset}).then((rows) => rows.map(AdminAuditEntry.fromJson).toList());
  Future<List<AdminRule>> rules() async => _rpcRows('admin_rules').then((rows) => rows.map(AdminRule.fromJson).toList());
  Future<void> setRuleStatus(String id, String status) async => _client.rpc('rule_version_set_status', params: <String, dynamic>{'p_id': id, 'p_status': status});

  Future<List<AdminTreatment>> treatments(AdminTreatmentQuery filter) async {
    final equals = <String, dynamic>{if (filter.status != null) 'status': filter.status, if (filter.scope != null) 'scope': filter.scope, if (filter.family != null) 'family': filter.family, if (filter.demoOnly) 'is_demo': true, if (filter.featuredOnly) 'is_featured': true};
    final rows = await _client.select('treatments', columns: '*,doctors(id,display_name),facilities(id,name)', equals: equals, searchColumn: filter.search.trim().isEmpty ? null : 'title', searchPattern: filter.search.trim().isEmpty ? null : '%${filter.search.trim()}%', orderBy: 'updated_at', ascending: false, rangeFrom: filter.page * 50, rangeTo: filter.page * 50 + 49);
    final ids = rows.map((row) => '${row['id']}').toList();
    if (ids.isNotEmpty) { final ratings = await _client.select('rating_summaries', equals: const <String, dynamic>{'target_type': 'treatment'}, inFilters: <String, List<String>>{'target_id': ids}); final byTarget = <String, Map<String, dynamic>>{for (final row in ratings) '${row['target_id']}': row}; for (final row in rows) row['rating_summaries'] = byTarget['${row['id']}']; }
    return rows.map(AdminTreatment.new).toList();
  }
  Future<AdminTreatment?> treatment(String id) async { final rows = await _client.select('treatments', equals: <String, dynamic>{'id': id}, limit: 1); return rows.isEmpty ? null : AdminTreatment(rows.first); }
  Future<List<AdminDoctor>> doctors() async => (await _client.select('doctors', columns: '*,facilities(id,name)', orderBy: 'display_name')).map(AdminDoctor.new).toList();
  Future<List<AdminFacility>> facilities() async => (await _client.select('facilities', orderBy: 'name')).map(AdminFacility.new).toList();
  Future<List<AdminTreatmentTag>> treatmentTags() async => (await _client.select('treatment_tags', orderBy: 'type')).map(AdminTreatmentTag.fromJson).toList();
  Future<String> upsertTreatment(Map<String, dynamic> payload) async => '${await _client.rpc('treatment_upsert', params: <String, dynamic>{'p_payload': payload})}';
  Future<void> setTreatmentStatus(String id, String status) async => _client.rpc('treatment_set_status', params: <String, dynamic>{'p_id': id, 'p_status': status});
  Future<String> upsertDoctor(Map<String, dynamic> payload) async => '${await _client.rpc('doctor_upsert', params: <String, dynamic>{'p_payload': payload})}';
  Future<String> upsertFacility(Map<String, dynamic> payload) async => '${await _client.rpc('facility_upsert', params: <String, dynamic>{'p_payload': payload})}';

  Future<List<AdminReview>> reviews(AdminReviewQuery filter) async {
    final rows = await _client.select('reviews', equals: <String, dynamic>{'status': filter.status, if (filter.targetType != null) 'target_type': filter.targetType}, orderBy: 'created_at', ascending: false, limit: 100);
    final labels = <String, String>{};
    for (final row in rows) { final author = '${row['author_id']}'; labels[author] ??= '${await _client.rpc('m24_review_author_label', params: <String, dynamic>{'p_author': author})}'; }
    await _attachReviewTargets(rows);
    return rows.map((row) => AdminReview(row, authorLabel: labels['${row['author_id']}'] ?? '')).toList();
  }
  Future<int> pendingReviewCount() async => (await _client.select('reviews', columns: 'id', equals: const <String, dynamic>{'status': 'pending'})).length;
  Future<void> moderateReview(String id, String status, String? note) async => _client.rpc('moderate_review', params: <String, dynamic>{'p_id': id, 'p_status': status, 'p_note': note});

  Future<void> _attachReviewTargets(List<Map<String, dynamic>> rows) async { for (final type in <String>['treatment', 'doctor', 'facility']) { final ids = rows.where((row) => row['target_type'] == type).map((row) => '${row['target_id']}').toSet().toList(); if (ids.isEmpty) continue; final table = type == 'treatment' ? 'treatments' : type == 'doctor' ? 'doctors' : 'facilities'; final label = type == 'treatment' ? 'title' : type == 'doctor' ? 'display_name' : 'name'; final targets = await _client.select(table, columns: 'id,$label', inFilters: <String, List<String>>{'id': ids}); final names = <String, String>{for (final row in targets) '${row['id']}': '${row[label]}'}; for (final row in rows.where((row) => row['target_type'] == type)) row['target_label'] = names['${row['target_id']}']; } }
  Map<String, dynamic> _range(DateTime from, DateTime to) => <String, dynamic>{'p_from': from.toUtc().toIso8601String(), 'p_to': to.toUtc().toIso8601String()};
  Future<List<Map<String, dynamic>>> _rpcRows(String name, [Map<String, dynamic>? params]) async { final result = await _client.rpc(name, params: params); if (result is! List) return <Map<String, dynamic>>[]; return result.whereType<Map>().map((row) { if (row.length == 1 && row.values.first is Map) return Map<String, dynamic>.from(row.values.first as Map); return Map<String, dynamic>.from(row); }).toList(); }
}

List<Map<String, dynamic>> _maps(dynamic value) => value is List ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList() : <Map<String, dynamic>>[];