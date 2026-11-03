class TreatmentSummary {
  const TreatmentSummary({required this.id, required this.title, this.summary, this.family, this.scope, this.evidenceLevel, this.priceFromCents, this.sessionMinutes, this.modality, this.doctorName, this.facilityName, this.city, this.coverUrl, this.ratingAverage, this.ratingCount = 0, this.isDemo = false, this.totalCount = 0});
  final String id, title;
  final String? summary, family, scope, evidenceLevel, modality, doctorName, facilityName, city, coverUrl;
  final int? priceFromCents, sessionMinutes;
  final double? ratingAverage;
  final int ratingCount, totalCount;
  final bool isDemo;

  factory TreatmentSummary.fromJson(Map<String, dynamic> json) => TreatmentSummary(id: json['id'].toString(), title: (json['title'] ?? '').toString(), summary: json['summary']?.toString(), family: json['family']?.toString(), scope: json['scope']?.toString(), evidenceLevel: json['evidence_level']?.toString(), priceFromCents: (json['price_from_cents'] as num?)?.toInt(), sessionMinutes: (json['session_minutes'] as num?)?.toInt(), modality: json['modality']?.toString(), doctorName: json['doctor_display_name']?.toString(), facilityName: json['facility_name']?.toString(), city: json['facility_city']?.toString(), coverUrl: json['cover_url']?.toString(), ratingAverage: (json['rating_avg'] as num?)?.toDouble(), ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0, isDemo: json['is_demo'] == true, totalCount: (json['total_count'] as num?)?.toInt() ?? 0);
}

class TreatmentFilters {
  const TreatmentFilters({this.query = '', this.scope, this.family, this.modality, this.city, this.duration, this.evidenceLevel, this.minRating, this.sort = 'pertinenza'});
  final String query, sort;
  final String? scope, family, modality, city, duration, evidenceLevel;
  final double? minRating;
  TreatmentFilters copyWith({String? query, String? scope, String? family, String? modality, String? city, String? duration, String? evidenceLevel, double? minRating, String? sort, bool clearScope = false, bool clearFamily = false, bool clearModality = false, bool clearCity = false, bool clearDuration = false, bool clearEvidence = false, bool clearRating = false}) => TreatmentFilters(query: query ?? this.query, scope: clearScope ? null : scope ?? this.scope, family: clearFamily ? null : family ?? this.family, modality: clearModality ? null : modality ?? this.modality, city: clearCity ? null : city ?? this.city, duration: clearDuration ? null : duration ?? this.duration, evidenceLevel: clearEvidence ? null : evidenceLevel ?? this.evidenceLevel, minRating: clearRating ? null : minRating ?? this.minRating, sort: sort ?? this.sort);
  Map<String, String> toQuery() => <String, String>{if (query.isNotEmpty) 'q': query, if (scope != null) 'scope': scope!, if (family != null) 'family': family!, if (modality != null) 'modality': modality!, if (city != null) 'city': city!, if (duration != null) 'duration': duration!, if (evidenceLevel != null) 'evidence': evidenceLevel!, if (minRating != null) 'rating': '$minRating', if (sort != 'pertinenza') 'sort': sort};
  factory TreatmentFilters.fromQuery(Map<String, String> query) => TreatmentFilters(query: query['q'] ?? '', scope: query['scope'], family: query['family'], modality: query['modality'], city: query['city'], duration: query['duration'], evidenceLevel: query['evidence'], minRating: double.tryParse(query['rating'] ?? ''), sort: query['sort'] ?? 'pertinenza');
}

class TreatmentSearchResult {
  const TreatmentSearchResult({required this.items, required this.total});
  final List<TreatmentSummary> items;
  final int total;
}

class TreatmentFacets {
  const TreatmentFacets({this.total = 0, this.scope = const {}, this.family = const {}, this.modality = const {}, this.city = const {}, this.evidence = const {}});
  final int total;
  final Map<String, int> scope, family, modality, city, evidence;
  factory TreatmentFacets.fromJson(Map<String, dynamic> json) {
    Map<String, int> counts(dynamic value) => value is Map ? value.map((key, value) => MapEntry(key.toString(), (value as num).toInt())) : <String, int>{};
    return TreatmentFacets(total: (json['total'] as num?)?.toInt() ?? 0, scope: counts(json['scope']), family: counts(json['family']), modality: counts(json['modality']), city: counts(json['city']), evidence: counts(json['evidence_level']));
  }
}

class TreatmentDetail {
  const TreatmentDetail(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'].toString();
  String get title => (data['title'] ?? '').toString();
  String? text(String key) => data[key]?.toString();
  int? integer(String key) => (data[key] as num?)?.toInt();
  bool flag(String key) => data[key] == true;
  Map<String, dynamic> map(String key) => Map<String, dynamic>.from(data[key] as Map? ?? const {});
  List<Map<String, dynamic>> list(String key) => (data[key] as List? ?? const []).whereType<Map>().map((value) => Map<String, dynamic>.from(value)).toList();
}

class TreatmentReview {
  const TreatmentReview(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'].toString();
  int get rating => (data['rating'] as num?)?.toInt() ?? 0;
  String get author => (data['author_label'] ?? '').toString();
  String get body => (data['body'] ?? '').toString();
  String? get title => data['title']?.toString();
  bool get verified => data['verified'] == true;
  DateTime? get createdAt => DateTime.tryParse(data['created_at']?.toString() ?? '');
  int get totalCount => (data['total_count'] as num?)?.toInt() ?? 0;
}

class CompareTreatment {
  const CompareTreatment(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'].toString();
  String get title => (data['title'] ?? '').toString();
}