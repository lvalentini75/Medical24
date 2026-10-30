/// Model of `public.biomarker_catalog` (M3 Motore di estrazione).
///
/// It is the institutional reference of the scientific board. Until a row is
/// `validated` with a board version it must be shown as a draft and never as
/// an institutional threshold.
library;

/// `catalog_status` enum.
enum CatalogStatus {
  draft('draft'),
  validated('validated'),
  retired('retired');

  const CatalogStatus(this.value);
  final String value;

  static CatalogStatus fromValue(String? v) => CatalogStatus.values.firstWhere(
      (CatalogStatus s) => s.value == v,
      orElse: () => CatalogStatus.draft);
}

List<String> _strings(Object? v) => v is List
    ? v.map((Object? e) => e.toString()).toList(growable: false)
    : const <String>[];

double? _num(Object? v) => v == null ? null : double.tryParse(v.toString());

/// Row of `public.biomarker_catalog`.
class Biomarker {
  const Biomarker({
    required this.code,
    required this.nameIt,
    required this.nameEn,
    required this.category,
    required this.unitCanonical,
    this.synonymsIt = const <String>[],
    this.synonymsEn = const <String>[],
    this.unitAlternatives = const <String, String>{},
    this.refLowM,
    this.refHighM,
    this.refLowF,
    this.refHighF,
    this.ageNote,
    this.plausibleMin,
    this.plausibleMax,
    this.safetyLow,
    this.safetyHigh,
    this.organs = const <String>[],
    this.notes,
    this.status = CatalogStatus.draft,
    this.boardVersion = 0,
  });

  final String code;
  final String nameIt;
  final String nameEn;
  final List<String> synonymsIt;
  final List<String> synonymsEn;
  final String category;
  final String unitCanonical;

  /// Read unit -> multiplicative factor towards [unitCanonical].
  /// The special value `IFCC` means the HbA1c formula.
  final Map<String, String> unitAlternatives;

  final double? refLowM;
  final double? refHighM;
  final double? refLowF;
  final double? refHighF;
  final String? ageNote;
  final double? plausibleMin;
  final double? plausibleMax;

  /// Board safety limits: beyond these the value is always a critical alert
  /// and no doctor threshold can silence it.
  final double? safetyLow;
  final double? safetyHigh;
  final List<String> organs;
  final String? notes;
  final CatalogStatus status;
  final int boardVersion;

  /// True while the board has not validated the row yet.
  bool get isDraft => status == CatalogStatus.draft;

  String name(String languageCode) => languageCode == 'en' ? nameEn : nameIt;

  List<String> synonyms(String languageCode) =>
      languageCode == 'en' ? synonymsEn : synonymsIt;

  factory Biomarker.fromJson(Map<String, dynamic> json) => Biomarker(
        code: json['code'].toString(),
        nameIt: (json['name_it'] ?? '').toString(),
        nameEn: (json['name_en'] ?? '').toString(),
        synonymsIt: _strings(json['synonyms_it']),
        synonymsEn: _strings(json['synonyms_en']),
        category: (json['category'] ?? '').toString(),
        unitCanonical: (json['unit_canonical'] ?? '').toString(),
        unitAlternatives: json['unit_alternatives'] is Map
            ? (json['unit_alternatives'] as Map).map(
                (Object? k, Object? v) =>
                    MapEntry<String, String>(k.toString(), v.toString()))
            : const <String, String>{},
        refLowM: _num(json['ref_low_m']),
        refHighM: _num(json['ref_high_m']),
        refLowF: _num(json['ref_low_f']),
        refHighF: _num(json['ref_high_f']),
        ageNote: json['age_note'] as String?,
        plausibleMin: _num(json['plausible_min']),
        plausibleMax: _num(json['plausible_max']),
        safetyLow: _num(json['safety_low']),
        safetyHigh: _num(json['safety_high']),
        organs: _strings(json['organs']),
        notes: json['notes'] as String?,
        status: CatalogStatus.fromValue(json['status'] as String?),
        boardVersion: (json['board_version'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'name_it': nameIt,
        'name_en': nameEn,
        'synonyms_it': synonymsIt,
        'synonyms_en': synonymsEn,
        'category': category,
        'unit_canonical': unitCanonical,
        'unit_alternatives': unitAlternatives,
        'ref_low_m': refLowM,
        'ref_high_m': refHighM,
        'ref_low_f': refLowF,
        'ref_high_f': refHighF,
        'age_note': ageNote,
        'plausible_min': plausibleMin,
        'plausible_max': plausibleMax,
        'safety_low': safetyLow,
        'safety_high': safetyHigh,
        'organs': organs,
        'notes': notes,
        'status': status.value,
        'board_version': boardVersion,
      };

  Biomarker copyWith({
    String? nameIt,
    String? nameEn,
    List<String>? synonymsIt,
    List<String>? synonymsEn,
    String? category,
    String? unitCanonical,
    Map<String, String>? unitAlternatives,
    CatalogStatus? status,
    int? boardVersion,
  }) =>
      Biomarker(
        code: code,
        nameIt: nameIt ?? this.nameIt,
        nameEn: nameEn ?? this.nameEn,
        synonymsIt: synonymsIt ?? this.synonymsIt,
        synonymsEn: synonymsEn ?? this.synonymsEn,
        category: category ?? this.category,
        unitCanonical: unitCanonical ?? this.unitCanonical,
        unitAlternatives: unitAlternatives ?? this.unitAlternatives,
        refLowM: refLowM,
        refHighM: refHighM,
        refLowF: refLowF,
        refHighF: refHighF,
        ageNote: ageNote,
        plausibleMin: plausibleMin,
        plausibleMax: plausibleMax,
        safetyLow: safetyLow,
        safetyHigh: safetyHigh,
        organs: organs,
        notes: notes,
        status: status ?? this.status,
        boardVersion: boardVersion ?? this.boardVersion,
      );
}

/// Institutional range resolved by `resolve_reference(subject_id, code)`.
class ReferenceRange {
  const ReferenceRange({
    this.refLow,
    this.refHigh,
    this.safetyLow,
    this.safetyHigh,
    this.boardVersion = 0,
  });

  final double? refLow;
  final double? refHigh;
  final double? safetyLow;
  final double? safetyHigh;
  final int boardVersion;

  bool get isEmpty => refLow == null && refHigh == null;

  factory ReferenceRange.fromJson(Map<String, dynamic> json) => ReferenceRange(
        refLow: _num(json['ref_low']),
        refHigh: _num(json['ref_high']),
        safetyLow: _num(json['safety_low']),
        safetyHigh: _num(json['safety_high']),
        boardVersion: (json['board_version'] as num?)?.toInt() ?? 0,
      );
}
