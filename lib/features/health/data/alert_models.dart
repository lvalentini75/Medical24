enum HealthAlertType { info, warning, critical }

class HealthAlert {
  const HealthAlert({required this.id, required this.type, required this.code, required this.level, required this.messageKey, required this.createdAt, this.readAt, this.biomarkerNameIt, this.biomarkerNameEn});
  final String id;
  final HealthAlertType type;
  final String code;
  final String level;
  final String messageKey;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? biomarkerNameIt;
  final String? biomarkerNameEn;
  bool get isUnread => readAt == null;
  String name(String language) => (language == 'en' ? biomarkerNameEn : biomarkerNameIt) ?? code;

  factory HealthAlert.fromJson(Map<String, dynamic> json) => HealthAlert(id: json['id'].toString(), type: HealthAlertType.values.firstWhere((HealthAlertType value) => value.name == json['type'], orElse: () => HealthAlertType.info), code: (json['code'] ?? '').toString(), level: (json['level'] ?? '').toString(), messageKey: (json['message_key'] ?? '').toString(), createdAt: DateTime.parse(json['created_at'].toString()).toLocal(), readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'].toString()).toLocal(), biomarkerNameIt: json['name_it']?.toString(), biomarkerNameEn: json['name_en']?.toString());
}