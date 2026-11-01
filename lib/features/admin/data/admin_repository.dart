import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medical24/features/admin/data/admin_models.dart';

class AdminRepository {
  AdminRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<bool> isAdmin() async {
    try {
      final dynamic result = await _client.rpc('has_role', params: <String, dynamic>{'p_role': 'admin'});
      return result == true;
    } on PostgrestException {
      final String? uid = _client.auth.currentUser?.id;
      if (uid == null) return false;
      final List<dynamic> rows = await _client.from('user_roles').select('role').eq('user_id', uid).eq('role', 'admin').limit(1);
      return rows.isNotEmpty;
    }
  }

  Future<AdminOverviewData> overview() async => AdminOverviewData.fromJson(Map<String, dynamic>.from(await _client.rpc('admin_overview') as Map));
  Future<List<AdminAiTask>> tasks() async => _rpcRows('admin_ai_tasks').then((rows) => rows.map(AdminAiTask.fromJson).toList());
  Future<List<AdminAiModel>> models() async => _rpcRows('admin_ai_models').then((rows) => rows.map(AdminAiModel.fromJson).toList());
  Future<List<AdminSetting>> settings() async => _rpcRows('admin_platform_settings').then((rows) => rows.map(AdminSetting.fromJson).toList());
  Future<List<AdminSetting>> settingHistory(String key) async => _rpcRows('admin_platform_settings_history', <String, dynamic>{'p_key': key}).then((rows) => rows.map(AdminSetting.fromJson).toList());
  Future<void> setTask(String id, Map<String, dynamic> patch) async => _client.rpc('ai_task_set', params: <String, dynamic>{'p_task': id, 'p_patch': patch});
  Future<void> setModel(String id, Map<String, dynamic> patch) async => _client.rpc('ai_model_set', params: <String, dynamic>{'p_id': id, 'p_patch': patch});
  Future<void> setSetting(AdminSetting setting, dynamic value) async => _client.rpc('platform_setting_set', params: <String, dynamic>{'p_key': setting.key, 'p_value': value, 'p_description': setting.description});
  Future<List<AdminPrompt>> prompts(String task) async => _rpcRows('admin_prompts', <String, dynamic>{'p_task': task}).then((rows) => rows.map(AdminPrompt.fromJson).toList());
  Future<String> approvePrompt(String id) async => '${await _client.rpc('ai_prompt_approve', params: <String, dynamic>{'p_id': id})}';
  Future<void> activatePrompt(String id) async => _client.rpc('ai_prompt_activate', params: <String, dynamic>{'p_id': id});
  Future<void> rollbackPrompt(String task) async => _client.rpc('ai_prompt_rollback', params: <String, dynamic>{'p_task': task});
  Future<void> createPrompt({required String task, required String systemPrompt, required String userTemplate, required Map<String, dynamic> toolSchema, required String notes}) async => _client.rpc('ai_prompt_create', params: <String, dynamic>{'p_task': task, 'p_system_prompt': systemPrompt, 'p_user_template': userTemplate, 'p_tool_schema': toolSchema, 'p_notes': notes});
  Future<List<AdminDryRunCase>> testPrompt(String id) async {
    final FunctionResponse response = await _client.functions.invoke('explain', body: <String, dynamic>{'dry_run': true, 'prompt_id': id});
    final Map<String, dynamic> body = Map<String, dynamic>.from(response.data as Map);
    return _maps(body['cases']).map(AdminDryRunCase.fromJson).toList();
  }
  Future<List<AdminUsageRow>> usage(DateTime from, DateTime to, String? task) async => _rpcRows('admin_usage', _range(from, to, task: task)).then((rows) => rows.map(AdminUsageRow.fromJson).toList());
  Future<List<AdminAiCall>> aiCalls(DateTime from, DateTime to, {String? task, String? status, int offset = 0}) async => _rpcRows('admin_ai_calls', <String, dynamic>{..._range(from, to, task: task), 'p_status': status, 'p_limit': 50, 'p_offset': offset}).then((rows) => rows.map(AdminAiCall.fromJson).toList());
  Future<List<AdminEvent>> events(DateTime from, DateTime to, {String? type, int offset = 0}) async => _rpcRows('admin_events', <String, dynamic>{..._range(from, to), 'p_type': type, 'p_limit': 100, 'p_offset': offset}).then((rows) => rows.map(AdminEvent.fromJson).toList());
  Future<List<AdminAuditEntry>> audit(DateTime from, DateTime to, {String? action, String? actor, int offset = 0}) async => _rpcRows('admin_audit', <String, dynamic>{..._range(from, to), 'p_action': action, 'p_actor': actor, 'p_limit': 100, 'p_offset': offset}).then((rows) => rows.map(AdminAuditEntry.fromJson).toList());
  Future<List<AdminRule>> rules() async => _rpcRows('admin_rules').then((rows) => rows.map(AdminRule.fromJson).toList());
  Future<void> setRuleStatus(String id, String status) async => _client.rpc('rule_version_set_status', params: <String, dynamic>{'p_id': id, 'p_status': status});

  Map<String, dynamic> _range(DateTime from, DateTime to, {String? task}) => <String, dynamic>{'p_from': from.toUtc().toIso8601String(), 'p_to': to.toUtc().toIso8601String(), if (task != null) 'p_task': task};

  Future<List<Map<String, dynamic>>> _rpcRows(String name, [Map<String, dynamic>? params]) async {
    final dynamic result = await _client.rpc(name, params: params);
    if (result is! List) return <Map<String, dynamic>>[];
    return result.whereType<Map>().map((Map row) {
      if (row.length == 1 && row.values.first is Map) return Map<String, dynamic>.from(row.values.first as Map);
      return Map<String, dynamic>.from(row);
    }).toList();
  }
}

List<Map<String, dynamic>> _maps(dynamic value) => value is List ? value.whereType<Map>().map((Map item) => Map<String, dynamic>.from(item)).toList() : <Map<String, dynamic>>[];