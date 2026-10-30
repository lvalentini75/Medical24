enum PreventionTab { controls, risks, history }

enum RiskFamily { cardiovascular, diabetes, kidney, fracture }

enum RiskLevel { low, medium, high }

class RiskScore {
  const RiskScore({required this.id, required this.family, required this.level, required this.score, required this.scoreUnit, required this.inputs, required this.factors, required this.ruleVersion, required this.computedAt, this.projectionScore, this.projectionLevel});
  final String id;
  final RiskFamily family;
  final RiskLevel level;
  final double score;
  final String scoreUnit;
  final Map<String, dynamic> inputs;
  final List<String> factors;
  final String ruleVersion;
  final DateTime computedAt;
  final double? projectionScore;
  final RiskLevel? projectionLevel;

  factory RiskScore.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? projection = json['projection_12m'] is Map ? Map<String, dynamic>.from(json['projection_12m'] as Map) : null;
    return RiskScore(id: json['id'].toString(), family: RiskFamily.values.byName(json['family'].toString()), level: RiskLevel.values.byName(json['level'].toString()), score: (json['score'] as num).toDouble(), scoreUnit: json['score_unit'].toString(), inputs: Map<String, dynamic>.from(json['inputs'] as Map? ?? const <String, dynamic>{}), factors: (json['factors'] as List? ?? const <dynamic>[]).map((dynamic value) => value.toString()).toList(growable: false), ruleVersion: (json['rule_version'] ?? '').toString(), computedAt: DateTime.parse(json['computed_at'].toString()).toLocal(), projectionScore: (projection?['score'] as num?)?.toDouble(), projectionLevel: projection?['level'] == null ? null : RiskLevel.values.byName(projection!['level'].toString()));
  }
}

enum RecommendationStatus { open, done, dismissed }

class PreventionRecommendation {
  const PreventionRecommendation({required this.id, required this.titleKey, required this.reasonKey, required this.category, required this.status, required this.origin, required this.ruleVersion, this.calendarId, this.code, this.organId, this.intervalMonths, this.dueAt, this.completedAt, this.documentId, this.dismissedAt, this.dismissReason});
  final String id;
  final String? calendarId;
  final String? code;
  final String titleKey;
  final String reasonKey;
  final String category;
  final String? organId;
  final int? intervalMonths;
  final DateTime? dueAt;
  final RecommendationStatus status;
  final String origin;
  final DateTime? completedAt;
  final String? documentId;
  final DateTime? dismissedAt;
  final String? dismissReason;
  final String ruleVersion;

  factory PreventionRecommendation.fromJson(Map<String, dynamic> json) => PreventionRecommendation(id: json['id'].toString(), calendarId: json['calendar_id']?.toString(), code: json['code']?.toString(), titleKey: (json['title_key'] ?? '').toString(), reasonKey: (json['reason_key'] ?? '').toString(), category: (json['category'] ?? '').toString(), organId: json['organ_id']?.toString(), intervalMonths: (json['interval_months'] as num?)?.toInt(), dueAt: _date(json['due_at']), status: RecommendationStatus.values.byName(json['status'].toString()), origin: (json['origin'] ?? 'rule').toString(), completedAt: _date(json['completed_at']), documentId: json['document_id']?.toString(), dismissedAt: _date(json['dismissed_at']), dismissReason: json['dismiss_reason']?.toString(), ruleVersion: (json['rule_version'] ?? '').toString());
}

class QuestionnaireState {
  const QuestionnaireState({required this.version, required this.questions, required this.answers, this.submittedAt, this.latestWeightKg, this.latestWeightAt});
  final String version;
  final List<String> questions;
  final Map<String, dynamic> answers;
  final DateTime? submittedAt;
  final double? latestWeightKg;
  final DateTime? latestWeightAt;
  bool get completed => submittedAt != null;
}

class PreventionSnapshot {
  const PreventionSnapshot({required this.recommendations, required this.risks, required this.riskHistory, required this.questionnaire, required this.biomarkerNames});
  final List<PreventionRecommendation> recommendations;
  final List<RiskScore> risks;
  final List<RiskScore> riskHistory;
  final QuestionnaireState questionnaire;
  final Map<String, Map<String, String>> biomarkerNames;
  List<PreventionRecommendation> get open => recommendations.where((PreventionRecommendation item) => item.status == RecommendationStatus.open).toList()..sort((PreventionRecommendation a, PreventionRecommendation b) => (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999)));
  List<PreventionRecommendation> get closed => recommendations.where((PreventionRecommendation item) => item.status != RecommendationStatus.open).toList()..sort((PreventionRecommendation a, PreventionRecommendation b) => (b.completedAt ?? b.dismissedAt ?? DateTime(1900)).compareTo(a.completedAt ?? a.dismissedAt ?? DateTime(1900)));
  RiskScore? scoreFor(RiskFamily family) => risks.where((RiskScore score) => score.family == family).firstOrNull;
}

DateTime? _date(dynamic value) => value == null ? null : DateTime.tryParse(value.toString())?.toLocal();