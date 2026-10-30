import 'package:medical24/core/models/observation.dart';

double? healthDouble(Object? value) => value == null ? null : double.tryParse(value.toString());
DateTime? healthDate(Object? value) => value == null ? null : DateTime.tryParse(value.toString());

/// One row returned by `biomarker_catalog_for_subject`.
class BiomarkerSummary {
  const BiomarkerSummary({required this.code, required this.nameIt, required this.nameEn, required this.unit, this.category = '', this.latestValue, this.latestAt, this.flag = ObservationFlag.unknown, this.valueCount = 0, this.essential = false, this.favorite = false, this.tracked = false});

  final String code;
  final String nameIt;
  final String nameEn;
  final String unit;
  final String category;
  final double? latestValue;
  final DateTime? latestAt;
  final ObservationFlag flag;
  final int valueCount;
  final bool essential;
  final bool favorite;
  final bool tracked;

  String name(String language) => language == 'en' ? nameEn : nameIt;

  factory BiomarkerSummary.fromJson(Map<String, dynamic> json) => BiomarkerSummary(
    code: json['code'].toString(), nameIt: (json['name_it'] ?? json['code']).toString(), nameEn: (json['name_en'] ?? json['code']).toString(), unit: (json['unit_canonical'] ?? '').toString(), category: (json['category'] ?? json['category_code'] ?? '').toString(), latestValue: healthDouble(json['latest_value']), latestAt: healthDate(json['latest_at']), flag: ObservationFlag.fromValue(json['flag']?.toString()), valueCount: (json['value_count'] as num?)?.toInt() ?? 0, essential: json['essential'] == true, favorite: json['favorite'] == true, tracked: json['tracked'] == true);

  BiomarkerSummary copyWith({bool? favorite, bool? tracked}) => BiomarkerSummary(code: code, nameIt: nameIt, nameEn: nameEn, unit: unit, category: category, latestValue: latestValue, latestAt: latestAt, flag: flag, valueCount: valueCount, essential: essential, favorite: favorite ?? this.favorite, tracked: tracked ?? this.tracked);
}

/// A dated point from `biomarker_series`, including all three range levels.
class BiomarkerPoint {
  const BiomarkerPoint({required this.id, required this.code, required this.at, required this.value, required this.unit, this.valueRaw, this.labLow, this.labHigh, this.institutionalLow, this.institutionalHigh, this.doctorLow, this.doctorHigh, this.flag = ObservationFlag.unknown, this.origin = ObservationOrigin.document, this.documentId, this.documentName, this.labName, this.createdAt});

  final String id;
  final String code;
  final DateTime at;
  final double value;
  final double? valueRaw;
  final String unit;
  final double? labLow;
  final double? labHigh;
  final double? institutionalLow;
  final double? institutionalHigh;
  final double? doctorLow;
  final double? doctorHigh;
  final ObservationFlag flag;
  final ObservationOrigin origin;
  final String? documentId;
  final String? documentName;
  final String? labName;
  final DateTime? createdAt;

  factory BiomarkerPoint.fromJson(Map<String, dynamic> json) => BiomarkerPoint(id: json['observation_id'].toString(), code: json['code'].toString(), at: healthDate(json['effective_at']) ?? DateTime.fromMillisecondsSinceEpoch(0), value: healthDouble(json['canonical_value']) ?? 0, valueRaw: healthDouble(json['value_raw'] ?? json['raw_value']), unit: (json['canonical_unit'] ?? '').toString(), labLow: healthDouble(json['lab_low']), labHigh: healthDouble(json['lab_high']), institutionalLow: healthDouble(json['institutional_low']), institutionalHigh: healthDouble(json['institutional_high']), doctorLow: healthDouble(json['doctor_low']), doctorHigh: healthDouble(json['doctor_high']), flag: ObservationFlag.fromValue(json['flag']?.toString()), origin: ObservationOrigin.fromValue(json['origin']?.toString()), documentId: json['document_id']?.toString(), documentName: (json['document_name'] ?? json['document_title'])?.toString(), labName: json['lab_name']?.toString(), createdAt: healthDate(json['created_at']));
}

/// Aggregate returned by `biomarker_stats`.
class BiomarkerStats {
  const BiomarkerStats({this.minimum, this.maximum, this.average, this.latestValue, this.latestAt, this.changeFromPrevious, this.valueCount = 0});
  final double? minimum;
  final double? maximum;
  final double? average;
  final double? latestValue;
  final DateTime? latestAt;
  final double? changeFromPrevious;
  final int valueCount;

  factory BiomarkerStats.fromJson(Map<String, dynamic> json) => BiomarkerStats(minimum: healthDouble(json['minimum']), maximum: healthDouble(json['maximum']), average: healthDouble(json['average']), latestValue: healthDouble(json['latest_value']), latestAt: healthDate(json['latest_at']), changeFromPrevious: healthDouble(json['change_from_previous']), valueCount: (json['value_count'] as num?)?.toInt() ?? 0);
}

/// One contiguous out-of-range episode.
class BiomarkerEpisode {
  const BiomarkerEpisode({required this.start, this.end, required this.level, this.items = const <EpisodeItem>[]});
  final DateTime start;
  final DateTime? end;
  final String level;
  final List<EpisodeItem> items;

  factory BiomarkerEpisode.fromJson(Map<String, dynamic> json) => BiomarkerEpisode(start: healthDate(json['episode_start']) ?? DateTime.fromMillisecondsSinceEpoch(0), end: healthDate(json['episode_end']), level: (json['level'] ?? 'unknown').toString(), items: (json['items'] as List? ?? const <dynamic>[]).whereType<Map>().map((Map item) => EpisodeItem.fromJson(Map<String, dynamic>.from(item))).toList(growable: false));
}

class EpisodeItem {
  const EpisodeItem({required this.id, required this.at, required this.value});
  final String id;
  final DateTime at;
  final double value;
  factory EpisodeItem.fromJson(Map<String, dynamic> json) => EpisodeItem(id: json['id'].toString(), at: healthDate(json['at']) ?? DateTime.fromMillisecondsSinceEpoch(0), value: healthDouble(json['value']) ?? 0);
}

class BiomarkerHistoryData {
  const BiomarkerHistoryData({required this.points, required this.stats, required this.episodes});
  final List<BiomarkerPoint> points;
  final BiomarkerStats stats;
  final List<BiomarkerEpisode> episodes;
}

/// Catalog metadata required to validate and save a manual measurement.
class ManualBiomarker {
  const ManualBiomarker({required this.code, required this.nameIt, required this.nameEn, required this.canonicalUnit, required this.unitAlternatives, this.plausibleMin, this.plausibleMax});

  final String code;
  final String nameIt;
  final String nameEn;
  final String canonicalUnit;
  final Map<String, double> unitAlternatives;
  final double? plausibleMin;
  final double? plausibleMax;

  String name(String language) => language == 'en' ? nameEn : nameIt;
  List<String> get units => <String>[canonicalUnit, ...unitAlternatives.keys.where((String unit) => unit != canonicalUnit)];
  double canonicalValue(double value, String unit) => value * (unit == canonicalUnit ? 1 : unitAlternatives[unit] ?? 1);

  factory ManualBiomarker.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> alternatives = Map<String, dynamic>.from(json['unit_alternatives'] as Map? ?? const <String, dynamic>{});
    return ManualBiomarker(code: json['code'].toString(), nameIt: json['name_it'].toString(), nameEn: json['name_en'].toString(), canonicalUnit: json['unit_canonical'].toString(), unitAlternatives: alternatives.map((String key, dynamic value) => MapEntry<String, double>(key, healthDouble(value) ?? 1)), plausibleMin: healthDouble(json['plausible_min']), plausibleMax: healthDouble(json['plausible_max']));
  }
}

class ManualObservationInput {
  const ManualObservationInput({required this.code, required this.value, required this.unit});
  final String code;
  final double value;
  final String unit;
}

enum HealthPeriod { all, year, months6, days90, days30 }

extension HealthPeriodDate on HealthPeriod {
  DateTime? from(DateTime now) => switch (this) { HealthPeriod.all => null, HealthPeriod.year => DateTime(now.year - 1, now.month, now.day), HealthPeriod.months6 => DateTime(now.year, now.month - 6, now.day), HealthPeriod.days90 => now.subtract(const Duration(days: 90)), HealthPeriod.days30 => now.subtract(const Duration(days: 30)) };
}