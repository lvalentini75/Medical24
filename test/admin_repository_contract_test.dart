import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/features/admin/data/admin_models.dart';
import 'package:medical24/features/admin/data/admin_repository.dart';

void main() {
  test('admin repository uses the declared RPC and table contracts', () async {
    final client = RecordingAdminPostgrestClient();
    final repository = AdminRepository(postgrest: client);
    final from = DateTime.parse('2026-01-01T01:00:00+01:00');
    final to = DateTime.parse('2026-01-02T01:00:00+01:00');
    const id = '00000000-0000-0000-0000-000000000001';
    const setting = AdminSetting(key: 'platform.test', value: true, isPublic: false, description: 'test', version: 1);

    await repository.isAdmin();
    await repository.overview();
    await repository.tasks();
    await repository.models();
    await repository.settings();
    await repository.settingHistory(setting.key);
    await repository.setTask('explain', <String, dynamic>{});
    await repository.setModel('model', <String, dynamic>{});
    await repository.setSetting(setting, false);
    await repository.prompts('explain');
    await repository.approvePrompt(id);
    await repository.activatePrompt(id);
    await repository.rollbackPrompt('explain');
    await repository.createPrompt(task: 'explain', systemPrompt: 'system', userTemplate: 'user', toolSchema: <String, dynamic>{}, notes: null);
    await repository.testPrompt(id);
    await repository.usage(from, to, null);
    await repository.aiCalls(from, to, task: null, status: null);
    await repository.events(from, to, type: null);
    await repository.audit(from, to, action: null, actor: null);
    await repository.rules();
    await repository.setRuleStatus(id, 'active');
    await repository.treatments(const AdminTreatmentQuery());
    await repository.treatment(id);
    await repository.doctors();
    await repository.facilities();
    await repository.treatmentTags();
    await repository.upsertTreatment(<String, dynamic>{});
    await repository.setTreatmentStatus(id, 'published');
    await repository.upsertDoctor(<String, dynamic>{});
    await repository.upsertFacility(<String, dynamic>{});
    await repository.reviews(const AdminReviewQuery());
    await repository.pendingReviewCount();
    await repository.moderateReview(id, 'approved', null);

    final expectedContracts = <String, Set<String>>{
      'admin_overview': <String>{}, 'admin_ai_tasks': <String>{}, 'ai_task_set': <String>{'p_task', 'p_patch'}, 'ai_model_set': <String>{'p_id', 'p_patch'},
      'platform_setting_set': <String>{'p_key', 'p_value', 'p_description'}, 'admin_prompts': <String>{'p_task'}, 'ai_prompt_approve': <String>{'p_id'}, 'ai_prompt_activate': <String>{'p_id'},
      'ai_prompt_rollback': <String>{'p_task'}, 'ai_prompt_create': <String>{'p_task', 'p_system_prompt', 'p_tool_schema', 'p_user_template', 'p_notes'},
      'admin_usage': <String>{'p_from', 'p_to', 'p_task'}, 'admin_ai_calls': <String>{'p_from', 'p_to', 'p_task', 'p_status', 'p_limit', 'p_offset'},
      'admin_events': <String>{'p_from', 'p_to', 'p_kind', 'p_limit', 'p_offset'}, 'admin_audit': <String>{'p_from', 'p_to', 'p_action', 'p_actor', 'p_limit', 'p_offset'},
      'admin_rules': <String>{}, 'rule_version_set_status': <String>{'p_id', 'p_status'}, 'treatment_upsert': <String>{'p_payload'}, 'treatment_set_status': <String>{'p_id', 'p_status'},
      'doctor_upsert': <String>{'p_payload'}, 'facility_upsert': <String>{'p_payload'}, 'm24_review_author_label': <String>{'p_author'}, 'moderate_review': <String>{'p_id', 'p_status', 'p_note'},
    };
    for (final entry in expectedContracts.entries) expect(client.rpcContracts[entry.key], entry.value, reason: entry.key);
    expect(client.tables, containsAll(<String>['ai_models', 'platform_settings', 'platform_settings_history', 'treatments', 'rating_summaries', 'doctors', 'facilities', 'treatment_tags', 'reviews']));
    final usage = client.calls.firstWhere((call) => call.name == 'admin_usage');
    expect(usage.params['p_from'], '2026-01-01T00:00:00.000Z');
    expect(usage.params['p_to'], '2026-01-02T00:00:00.000Z');
    expect(usage.params['p_task'], isNull);
    expect(client.functionBodies.single, const MapEntry<String, Map<String, dynamic>>('explain', <String, dynamic>{'dry_run': true, 'prompt_id': id}));
  });
}

class RecordedRpc {
  const RecordedRpc(this.name, this.params);
  final String name;
  final Map<String, dynamic> params;
}

class RecordingAdminPostgrestClient implements AdminPostgrestClient {
  final List<RecordedRpc> calls = <RecordedRpc>[];
  final List<String> tables = <String>[];
  final List<MapEntry<String, Map<String, dynamic>>> functionBodies = <MapEntry<String, Map<String, dynamic>>>[];
  Map<String, Set<String>> get rpcContracts => <String, Set<String>>{for (final call in calls) call.name: call.params.keys.toSet()};

  @override
  Future<dynamic> rpc(String name, {Map<String, dynamic>? params}) async {
    calls.add(RecordedRpc(name, params ?? <String, dynamic>{}));
    if (name == 'admin_overview') return <String, dynamic>{};
    if (name == 'm24_review_author_label') return 'Utente A.';
    if (<String>{'ai_prompt_create', 'ai_prompt_rollback', 'treatment_upsert', 'doctor_upsert', 'facility_upsert'}.contains(name)) return '00000000-0000-0000-0000-000000000001';
    return <dynamic>[];
  }

  @override
  Future<List<Map<String, dynamic>>> select(String table, {String columns = '*', Map<String, dynamic> equals = const <String, dynamic>{}, Map<String, List<String>> inFilters = const <String, List<String>>{}, String? searchColumn, String? searchPattern, String? orderBy, bool ascending = true, int? limit, int? rangeFrom, int? rangeTo}) async {
    tables.add(table);
    if (table == 'reviews' && columns == '*') return <Map<String, dynamic>>[<String, dynamic>{'id': 'r1', 'author_id': '00000000-0000-0000-0000-000000000001', 'target_type': 'treatment', 'target_id': 't1'}];
    if (table == 'treatments' && columns.startsWith('*,doctors')) return <Map<String, dynamic>>[<String, dynamic>{'id': 't1'}];
    return <Map<String, dynamic>>[];
  }

  @override
  Future<dynamic> invoke(String function, Map<String, dynamic> body) async { functionBodies.add(MapEntry<String, Map<String, dynamic>>(function, body)); return <String, dynamic>{'cases': <dynamic>[]}; }
}