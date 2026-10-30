import 'package:medical24/core/models/observation.dart';
import 'package:medical24/features/health/data/alert_models.dart';

class HomeValue {
  const HomeValue({required this.code, required this.value, required this.unit, required this.effectiveAt, required this.flag, this.valueRaw, this.nameIt, this.nameEn});
  final String code;
  final double value;
  final String unit;
  final double? valueRaw;
  final DateTime effectiveAt;
  final ObservationFlag flag;
  final String? nameIt;
  final String? nameEn;
  String name(String language) => (language == 'en' ? nameEn : nameIt) ?? code;
  factory HomeValue.fromJson(Map<String, dynamic> json) => HomeValue(code: json['code'].toString(), value: double.tryParse(json['value'].toString()) ?? 0, valueRaw: double.tryParse((json['value_raw'] ?? '').toString()), unit: (json['unit'] ?? '').toString(), effectiveAt: DateTime.parse(json['effective_at'].toString()).toLocal(), flag: ObservationFlag.fromValue(json['flag']?.toString()), nameIt: json['name_it']?.toString(), nameEn: json['name_en']?.toString());
}

class HomeDocument {
  const HomeDocument({required this.id, required this.title, required this.status, this.documentDate, this.createdAt});
  final String id;
  final String title;
  final String status;
  final DateTime? documentDate;
  final DateTime? createdAt;
  factory HomeDocument.fromJson(Map<String, dynamic> json) => HomeDocument(id: json['id'].toString(), title: (json['title'] ?? '').toString(), status: (json['status'] ?? '').toString(), documentDate: json['document_date'] == null ? null : DateTime.tryParse(json['document_date'].toString()), createdAt: json['created_at'] == null ? null : DateTime.tryParse(json['created_at'].toString()));
}

class HomeCounts {
  const HomeCounts({this.observations = 0, this.unreadAlerts = 0, this.documents = 0, this.symptoms = 0});
  final int observations;
  final int unreadAlerts;
  final int documents;
  final int symptoms;
  factory HomeCounts.fromJson(Map<String, dynamic> json) => HomeCounts(observations: (json['observations'] as num?)?.toInt() ?? 0, unreadAlerts: (json['unread_alerts'] as num?)?.toInt() ?? 0, documents: (json['documents'] as num?)?.toInt() ?? 0, symptoms: (json['symptoms'] as num?)?.toInt() ?? 0);
}

class HomeSnapshot {
  const HomeSnapshot({required this.values, required this.unreadAlerts, required this.documentsToReview, this.latestDocument, required this.counts});
  final List<HomeValue> values;
  final List<HealthAlert> unreadAlerts;
  final List<HomeDocument> documentsToReview;
  final HomeDocument? latestDocument;
  final HomeCounts counts;
  bool get isEmpty => counts.observations == 0 && counts.documents == 0 && counts.symptoms == 0 && counts.unreadAlerts == 0;
  factory HomeSnapshot.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? latest = json['latest_document'] is Map ? Map<String, dynamic>.from(json['latest_document'] as Map) : null;
    return HomeSnapshot(values: (json['values'] as List? ?? const <dynamic>[]).whereType<Map>().map((Map row) => HomeValue.fromJson(Map<String, dynamic>.from(row))).toList(), unreadAlerts: (json['unread_alerts'] as List? ?? const <dynamic>[]).whereType<Map>().map((Map row) => HealthAlert.fromJson(Map<String, dynamic>.from(row))).toList(), documentsToReview: (json['documents_to_review'] as List? ?? const <dynamic>[]).whereType<Map>().map((Map row) => HomeDocument.fromJson(Map<String, dynamic>.from(row))).toList(), latestDocument: latest == null ? null : HomeDocument.fromJson(latest), counts: HomeCounts.fromJson(Map<String, dynamic>.from(json['counts'] as Map? ?? const <String, dynamic>{})));
  }
}