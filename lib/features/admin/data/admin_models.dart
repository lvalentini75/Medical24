class AdminOverviewData {
  const AdminOverviewData({required this.usersTotal, required this.usersActive7d, required this.usersActive30d, required this.documents, required this.extractions, required this.costToday, required this.costMonth, required this.errors, required this.tasks, this.lastHealth});
  final int usersTotal, usersActive7d, usersActive30d, documents;
  final Map<String, int> extractions, errors;
  final Map<String, int> costToday, costMonth;
  final List<AdminTaskState> tasks;
  final AdminHealth? lastHealth;

  factory AdminOverviewData.fromJson(Map<String, dynamic> json) => AdminOverviewData(
    usersTotal: _integer(json['users_total']), usersActive7d: _integer(json['users_active_7d']), usersActive30d: _integer(json['users_active_30d']), documents: _integer(json['documents']),
    extractions: _intMap(json['extractions_7d']), errors: _intMap(json['errors_24h']), costToday: _intMap(json['cost_today_by_task']), costMonth: _intMap(json['cost_month_by_task']),
    tasks: _maps(json['tasks']).map(AdminTaskState.fromJson).toList(), lastHealth: json['last_health'] is Map ? AdminHealth.fromJson(Map<String, dynamic>.from(json['last_health'] as Map)) : null);
}

class AdminTaskState {
  const AdminTaskState({required this.id, required this.enabled, this.pausedUntil});
  final String id;
  final bool enabled;
  final DateTime? pausedUntil;
  factory AdminTaskState.fromJson(Map<String, dynamic> json) => AdminTaskState(id: '${json['id']}', enabled: json['enabled'] == true, pausedUntil: DateTime.tryParse('${json['paused_until'] ?? ''}'));
  bool get paused => pausedUntil?.isAfter(DateTime.now()) ?? false;
}

class AdminHealth {
  const AdminHealth({required this.at, required this.status, required this.details});
  final DateTime? at;
  final String status;
  final Map<String, dynamic> details;
  factory AdminHealth.fromJson(Map<String, dynamic> json) => AdminHealth(at: DateTime.tryParse('${json['at'] ?? ''}'), status: '${json['status'] ?? ''}', details: json['details'] is Map ? Map<String, dynamic>.from(json['details'] as Map) : <String, dynamic>{});
}

class AdminAiTask {
  const AdminAiTask({required this.id, required this.description, required this.model, this.fallbackModel, required this.enabledFallback, this.promptVersion, this.dailyBudgetMicroUsd, required this.spentToday, required this.maxOutputTokens, required this.enabled, required this.budgetAction, this.pausedUntil, this.perUserDailyLimit, required this.requiresSecondApproval, required this.requestOptions});
  final String id, description, model, budgetAction;
  final String? fallbackModel, promptVersion;
  final bool enabledFallback, enabled, requiresSecondApproval;
  final int? dailyBudgetMicroUsd, perUserDailyLimit;
  final int spentToday, maxOutputTokens;
  final DateTime? pausedUntil;
  final Map<String, dynamic> requestOptions;
  factory AdminAiTask.fromJson(Map<String, dynamic> j) => AdminAiTask(id: '${j['id']}', description: '${j['description'] ?? ''}', model: '${j['model'] ?? j['model_id'] ?? ''}', fallbackModel: j['fallback_model']?.toString() ?? j['fallback_model_id']?.toString(), enabledFallback: j['enabled_fallback'] == true || j['fallback_model'] != null, promptVersion: j['prompt_version']?.toString(), dailyBudgetMicroUsd: _nullableInt(j['daily_budget_micro_usd']), spentToday: _integer(j['spent_today']), maxOutputTokens: _integer(j['max_output_tokens'], fallback: 1), enabled: j['enabled'] != false, budgetAction: '${j['budget_action'] ?? 'alert'}', pausedUntil: DateTime.tryParse('${j['paused_until'] ?? ''}'), perUserDailyLimit: _nullableInt(j['per_user_daily_limit']), requiresSecondApproval: j['requires_second_approval'] == true, requestOptions: j['request_options'] is Map ? Map<String, dynamic>.from(j['request_options'] as Map) : <String, dynamic>{});
}

class AdminAiModel {
  const AdminAiModel({required this.id, required this.provider, required this.displayName, this.priceIn, this.priceOut, this.priceCached, this.contextWindow, required this.status});
  final String id, provider, displayName, status;
  final int? priceIn, priceOut, priceCached, contextWindow;
  factory AdminAiModel.fromJson(Map<String, dynamic> j) => AdminAiModel(id: '${j['id']}', provider: '${j['provider'] ?? ''}', displayName: '${j['display_name'] ?? ''}', priceIn: _nullableInt(j['price_in_micro_usd_per_mtok']), priceOut: _nullableInt(j['price_out_micro_usd_per_mtok']), priceCached: _nullableInt(j['price_cached_in_micro_usd_per_mtok']), contextWindow: _nullableInt(j['context_window']), status: '${j['status'] ?? 'active'}');
}

class AdminSetting {
  const AdminSetting({required this.key, required this.value, required this.isPublic, this.description, required this.version, this.updatedAt});
  final String key;
  final dynamic value;
  final bool isPublic;
  final String? description;
  final int version;
  final DateTime? updatedAt;
  factory AdminSetting.fromJson(Map<String, dynamic> j) => AdminSetting(key: '${j['key']}', value: j['value'], isPublic: j['is_public'] == true, description: j['description']?.toString(), version: _integer(j['version']), updatedAt: DateTime.tryParse('${j['updated_at'] ?? ''}'));
}

class AdminPrompt {
  const AdminPrompt({required this.id, required this.taskId, required this.version, required this.status, required this.systemPrompt, required this.userTemplate, required this.toolSchema, this.notes, this.createdBy, this.createdAt, this.approvedBy, this.approvedAt, this.activatedAt, this.lastTest});
  final String id, taskId, version, status, systemPrompt, userTemplate;
  final Map<String, dynamic> toolSchema;
  final String? notes, createdBy, approvedBy;
  final DateTime? createdAt, approvedAt, activatedAt;
  final AdminPromptTest? lastTest;
  factory AdminPrompt.fromJson(Map<String, dynamic> j) => AdminPrompt(id: '${j['id']}', taskId: '${j['task_id'] ?? j['task'] ?? ''}', version: '${j['version'] ?? ''}', status: '${j['status'] ?? 'draft'}', systemPrompt: '${j['system_prompt'] ?? ''}', userTemplate: '${j['user_template'] ?? ''}', toolSchema: _map(j['tool_schema']), notes: j['notes']?.toString(), createdBy: j['created_by']?.toString(), createdAt: _date(j['created_at']), approvedBy: j['approved_by']?.toString(), approvedAt: _date(j['approved_at']), activatedAt: _date(j['activated_at']), lastTest: j['last_test'] is Map ? AdminPromptTest.fromJson(Map<String, dynamic>.from(j['last_test'] as Map)) : null);
}

class AdminPromptTest {
  const AdminPromptTest({required this.passed, required this.cases, this.at});
  final bool passed;
  final DateTime? at;
  final List<AdminDryRunCase> cases;
  factory AdminPromptTest.fromJson(Map<String, dynamic> j) => AdminPromptTest(passed: j['passed'] == true, at: _date(j['at'] ?? j['created_at']), cases: _maps(j['cases']).map(AdminDryRunCase.fromJson).toList());
}

class AdminDryRunCase {
  const AdminDryRunCase({required this.name, required this.text, required this.filterPassed, required this.closingPresent});
  final String name, text;
  final bool filterPassed, closingPresent;
  factory AdminDryRunCase.fromJson(Map<String, dynamic> j) => AdminDryRunCase(name: '${j['case'] ?? j['name'] ?? ''}', text: '${j['text'] ?? j['error'] ?? ''}', filterPassed: j['filter_passed'] == true || j['passed'] == true, closingPresent: j['closing_present'] == true);
}

class AdminUsageRow {
  const AdminUsageRow({required this.day, required this.task, required this.model, required this.calls, required this.ok, required this.errors, required this.cached, required this.tokensIn, required this.tokensCached, required this.tokensOut, required this.costMicroUsd, required this.latencyAvg, required this.latencyP95});
  final DateTime? day;
  final String task, model;
  final int calls, ok, errors, cached, tokensIn, tokensCached, tokensOut, costMicroUsd, latencyAvg, latencyP95;
  factory AdminUsageRow.fromJson(Map<String, dynamic> j) => AdminUsageRow(day: _date(j['day']), task: '${j['task_id'] ?? j['task'] ?? ''}', model: '${j['model_id'] ?? j['model'] ?? ''}', calls: _integer(j['calls']), ok: _integer(j['ok']), errors: _integer(j['errors']), cached: _integer(j['cached'] ?? j['cache']), tokensIn: _integer(j['tokens_in']), tokensCached: _integer(j['tokens_cached_in'] ?? j['tokens_cache']), tokensOut: _integer(j['tokens_out']), costMicroUsd: _integer(j['cost_micro_usd'] ?? j['cost']), latencyAvg: _integer(j['latency_avg_ms'] ?? j['avg_latency_ms']), latencyP95: _integer(j['latency_p95_ms'] ?? j['p95_latency_ms']));
}

class AdminAiCall {
  const AdminAiCall({required this.id, required this.task, required this.model, required this.status, required this.details, this.at});
  final String id, task, model, status;
  final DateTime? at;
  final Map<String, dynamic> details;
  factory AdminAiCall.fromJson(Map<String, dynamic> j) => AdminAiCall(id: '${j['id']}', task: '${j['task_id'] ?? j['task'] ?? ''}', model: '${j['model_id'] ?? j['model'] ?? ''}', status: '${j['status'] ?? ''}', at: _date(j['created_at'] ?? j['at']), details: j);
}

class AdminEvent {
  const AdminEvent({required this.id, required this.type, required this.details, this.at});
  final String id, type;
  final DateTime? at;
  final Map<String, dynamic> details;
  factory AdminEvent.fromJson(Map<String, dynamic> j) => AdminEvent(id: '${j['id']}', type: '${j['event_type'] ?? j['type'] ?? ''}', at: _date(j['created_at'] ?? j['at']), details: _map(j['details'].toString() == 'null' ? j : j['details']));
}

class AdminAuditEntry {
  const AdminAuditEntry({required this.id, required this.action, required this.actor, required this.details, this.at});
  final String id, action, actor;
  final DateTime? at;
  final Map<String, dynamic> details;
  factory AdminAuditEntry.fromJson(Map<String, dynamic> j) => AdminAuditEntry(id: '${j['id']}', action: '${j['action'] ?? ''}', actor: '${j['actor_id'] ?? j['actor'] ?? ''}', at: _date(j['created_at'] ?? j['at']), details: _map(j['details'].toString() == 'null' ? j : j['details']));
}

class AdminRule {
  const AdminRule({required this.id, required this.type, required this.version, required this.status, required this.definition, this.approvedBy, this.approvedAt, this.updatedAt});
  final String id, type, version, status;
  final String? approvedBy;
  final DateTime? approvedAt, updatedAt;
  final Map<String, dynamic> definition;
  factory AdminRule.fromJson(Map<String, dynamic> j) => AdminRule(id: '${j['id'] ?? j['version_id']}', type: '${j['rule_type'] ?? j['type'] ?? ''}', version: '${j['version'] ?? ''}', status: '${j['status'] ?? 'draft'}', definition: _map(j['definition']), approvedBy: j['approved_by']?.toString(), approvedAt: _date(j['approved_at']), updatedAt: _date(j['updated_at']));
}

int _integer(dynamic value, {int fallback = 0}) => value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
int? _nullableInt(dynamic value) => value == null ? null : _integer(value);
Map<String, int> _intMap(dynamic value) => value is Map ? value.map((dynamic key, dynamic value) => MapEntry('$key', _integer(value))) : <String, int>{};
List<Map<String, dynamic>> _maps(dynamic value) => value is List ? value.whereType<Map>().map((Map item) => Map<String, dynamic>.from(item)).toList() : <Map<String, dynamic>>[];
Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
DateTime? _date(dynamic value) => DateTime.tryParse('${value ?? ''}');