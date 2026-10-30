import 'package:medical24/core/models/observation.dart';

enum OrganHealthState { ok, monitor, attention, missing }

extension OrganHealthStateValue on OrganHealthState {
  static OrganHealthState fromValue(Object? value) => switch (value?.toString()) { 'ok' => OrganHealthState.ok, 'monitor' => OrganHealthState.monitor, 'attention' => OrganHealthState.attention, _ => OrganHealthState.missing };
  int? get comparisonRank => switch (this) { OrganHealthState.ok => 0, OrganHealthState.monitor => 1, OrganHealthState.attention => 2, OrganHealthState.missing => null };
}

DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse(value.toString());
double? _double(Object? value) => value == null ? null : double.tryParse(value.toString());

class OrganOverview {
  const OrganOverview({required this.id, required this.sortOrder, required this.nameIt, required this.nameEn, required this.descriptionIt, required this.descriptionEn, required this.icon, required this.anchorX, required this.anchorY, this.sex = 'all', this.state, this.confidence = 0, this.stressScore, this.computedAt, this.presentCodes = 0, this.mappedCodes = 0});
  final String id, nameIt, nameEn, descriptionIt, descriptionEn, icon, sex;
  final int sortOrder, presentCodes, mappedCodes;
  final double anchorX, anchorY, confidence;
  final double? stressScore;
  final OrganHealthState? state;
  final DateTime? computedAt;
  String name(String language) => language == 'en' ? nameEn : nameIt;
  String description(String language) => language == 'en' ? descriptionEn : descriptionIt;
  factory OrganOverview.fromJson(Map<String, dynamic> json) => OrganOverview(id: json['organ_id'].toString(), sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0, nameIt: (json['name_it'] ?? '').toString(), nameEn: (json['name_en'] ?? '').toString(), descriptionIt: (json['description_it'] ?? '').toString(), descriptionEn: (json['description_en'] ?? '').toString(), icon: (json['icon'] ?? '').toString(), anchorX: _double(json['anchor_x']) ?? .5, anchorY: _double(json['anchor_y']) ?? .5, sex: (json['sex'] ?? 'all').toString(), state: json['state'] == null ? null : OrganHealthStateValue.fromValue(json['state']), confidence: _double(json['confidence']) ?? 0, stressScore: _double(json['stress_score']), computedAt: _date(json['computed_at']), presentCodes: (json['present_codes'] as num?)?.toInt() ?? 0, mappedCodes: (json['mapped_codes'] as num?)?.toInt() ?? 0);
}

class OrganBiomarker {
  const OrganBiomarker({required this.code, required this.nameIt, required this.nameEn, required this.unit, this.latestValue, this.latestAt, this.flag = ObservationFlag.unknown, this.weight = 1, this.isPresent = false});
  final String code, nameIt, nameEn, unit;
  final double? latestValue;
  final DateTime? latestAt;
  final ObservationFlag flag;
  final int weight;
  final bool isPresent;
  String name(String language) => language == 'en' ? nameEn : nameIt;
  factory OrganBiomarker.fromJson(Map<String, dynamic> json) => OrganBiomarker(code: json['code'].toString(), nameIt: (json['name_it'] ?? json['code']).toString(), nameEn: (json['name_en'] ?? json['code']).toString(), unit: (json['unit_canonical'] ?? '').toString(), latestValue: _double(json['latest_value']), latestAt: _date(json['latest_at']), flag: ObservationFlag.fromValue(json['flag']?.toString()), weight: (json['weight'] as num?)?.toInt() ?? 1, isPresent: json['is_present'] == true);
}

class OrganHistoryInput {
  const OrganHistoryInput({required this.code, required this.observationId, required this.flag, required this.effectiveAt, required this.weight});
  final String code, observationId;
  final ObservationFlag flag;
  final DateTime effectiveAt;
  final int weight;
  factory OrganHistoryInput.fromJson(Map<String, dynamic> json) => OrganHistoryInput(code: json['code'].toString(), observationId: json['observation_id'].toString(), flag: ObservationFlag.fromValue(json['flag']?.toString()), effectiveAt: _date(json['effective_at']) ?? DateTime.fromMillisecondsSinceEpoch(0), weight: (json['weight'] as num?)?.toInt() ?? 1);
}

class OrganHistoryEntry {
  const OrganHistoryEntry({required this.id, required this.state, required this.confidence, required this.inputs, required this.ruleVersion, required this.computedAt, this.stressScore});
  final String id, ruleVersion;
  final OrganHealthState state;
  final double confidence;
  final double? stressScore;
  final List<OrganHistoryInput> inputs;
  final DateTime computedAt;
  factory OrganHistoryEntry.fromJson(Map<String, dynamic> json) => OrganHistoryEntry(id: json['id'].toString(), state: OrganHealthStateValue.fromValue(json['state']), confidence: _double(json['confidence']) ?? 0, stressScore: _double(json['stress_score']), inputs: (json['inputs'] as List? ?? const <dynamic>[]).whereType<Map>().map((Map row) => OrganHistoryInput.fromJson(Map<String, dynamic>.from(row))).toList(growable: false), ruleVersion: (json['rule_version'] ?? '').toString(), computedAt: _date(json['computed_at']) ?? DateTime.fromMillisecondsSinceEpoch(0));
}

class OrganComparison {
  const OrganComparison({this.currentState, this.currentStressScore, this.currentAt, this.state6m, this.stressScore6m, this.at6m, this.state12m, this.stressScore12m, this.at12m});
  final OrganHealthState? currentState, state6m, state12m;
  final DateTime? currentAt, at6m, at12m;
  final double? currentStressScore, stressScore6m, stressScore12m;
  factory OrganComparison.fromJson(Map<String, dynamic> json) => OrganComparison(currentState: json['current_state'] == null ? null : OrganHealthStateValue.fromValue(json['current_state']), currentStressScore: _double(json['current_stress_score']), currentAt: _date(json['current_at']), state6m: json['state_6m'] == null ? null : OrganHealthStateValue.fromValue(json['state_6m']), stressScore6m: _double(json['stress_score_6m']), at6m: _date(json['at_6m']), state12m: json['state_12m'] == null ? null : OrganHealthStateValue.fromValue(json['state_12m']), stressScore12m: _double(json['stress_score_12m']), at12m: _date(json['at_12m']));
}

class OrganEpisode {
  const OrganEpisode({required this.start, this.end});
  final DateTime start;
  final DateTime? end;
  factory OrganEpisode.fromJson(Map<String, dynamic> json) => OrganEpisode(start: _date(json['episode_start']) ?? DateTime.fromMillisecondsSinceEpoch(0), end: _date(json['episode_end']));
}

class OrganRuleVersion {
  const OrganRuleVersion({required this.version, required this.notes});
  final String version, notes;
  factory OrganRuleVersion.fromJson(Map<String, dynamic> json) => OrganRuleVersion(version: (json['version'] ?? '').toString(), notes: (json['notes'] ?? '').toString());
}