/// Models of `public.observations` and `public.extractions` (M3 Motore).
///
/// `observations` is append-only: a correction never overwrites a value, it
/// creates a new row that supersedes the previous one.
library;

/// `extraction_status` enum.
enum ExtractionStatus {
  queued('queued'),
  classifying('classifying'),
  extracting('extracting'),
  normalizing('normalizing'),
  done('done'),
  needsReview('needs_review'),
  failed('failed');

  const ExtractionStatus(this.value);
  final String value;

  static ExtractionStatus fromValue(String? v) =>
      ExtractionStatus.values.firstWhere((ExtractionStatus s) => s.value == v,
          orElse: () => ExtractionStatus.queued);

  bool get isRunning =>
      this == queued ||
      this == classifying ||
      this == extracting ||
      this == normalizing;

  bool get isFinished =>
      this == done || this == needsReview || this == failed;
}

/// `observation_origin` enum.
enum ObservationOrigin {
  document('document'),
  manual('manual'),
  device('device');

  const ObservationOrigin(this.value);
  final String value;

  static ObservationOrigin fromValue(String? v) =>
      ObservationOrigin.values.firstWhere((ObservationOrigin o) => o.value == v,
          orElse: () => ObservationOrigin.document);
}

/// `observation_flag` enum: position against the board thresholds.
enum ObservationFlag {
  below('below'),
  within('within'),
  above('above'),
  criticalLow('critical_low'),
  criticalHigh('critical_high'),
  unknown('unknown');

  const ObservationFlag(this.value);
  final String value;

  static ObservationFlag fromValue(String? v) =>
      ObservationFlag.values.firstWhere((ObservationFlag f) => f.value == v,
          orElse: () => ObservationFlag.unknown);

  bool get isCritical => this == criticalLow || this == criticalHigh;
  bool get isOutOfRange => this != within && this != unknown;
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString());

double? _num(Object? v) => v == null ? null : double.tryParse(v.toString());

/// Row of `public.observations`.
class Observation {
  const Observation({
    required this.id,
    required this.subjectId,
    required this.code,
    required this.effectiveAt,
    this.displayName = '',
    this.valueNum,
    this.valueText,
    this.unit,
    this.valueRaw,
    this.unitRaw,
    this.labLow,
    this.labHigh,
    this.refLow,
    this.refHigh,
    this.flag = ObservationFlag.unknown,
    this.origin = ObservationOrigin.document,
    this.documentId,
    this.extractionId,
    this.confidence,
    this.needsReview = false,
    this.confirmedAt,
    this.confirmedBy,
    this.supersedesId,
    this.supersededAt,
    this.catalogVersion = 0,
    this.ruleVersion = 'board-0',
    this.labName,
    this.createdAt,
  });

  final String id;
  final String subjectId;
  final String code;
  final String displayName;

  /// Value in the canonical unit of the catalog.
  final double? valueNum;
  final String? valueText;
  final String? unit;

  /// Value and unit exactly as printed on the report.
  final double? valueRaw;
  final String? unitRaw;

  /// Range printed by the laboratory (first of the three levels).
  final double? labLow;
  final double? labHigh;

  /// Institutional range of the board (second level).
  final double? refLow;
  final double? refHigh;

  final ObservationFlag flag;
  final DateTime effectiveAt;
  final ObservationOrigin origin;
  final String? documentId;
  final String? extractionId;
  final double? confidence;

  /// True while the user has not confirmed a low-confidence value.
  final bool needsReview;
  final DateTime? confirmedAt;
  final String? confirmedBy;

  /// Row this one replaces, when it is a correction.
  final String? supersedesId;
  final DateTime? supersededAt;
  final int catalogVersion;
  final String ruleVersion;
  final String? labName;
  final DateTime? createdAt;

  bool get isCurrent => supersededAt == null;
  bool get isConfirmed => confirmedAt != null;
  bool get hasLabRange => labLow != null || labHigh != null;
  bool get hasBoardRange => refLow != null || refHigh != null;

  /// Value to show, canonical first, raw as a fallback.
  String displayValue() {
    if (valueNum != null) {
      final String n = valueNum! == valueNum!.roundToDouble() &&
              valueNum!.abs() < 1000
          ? valueNum!.toStringAsFixed(valueNum!.abs() < 10 ? 1 : 0)
          : valueNum!.toStringAsFixed(2);
      return unit == null || unit!.isEmpty ? n : '$n $unit';
    }
    return valueText ?? '—';
  }

  factory Observation.fromJson(Map<String, dynamic> json) => Observation(
        id: json['id'].toString(),
        subjectId: json['subject_id'].toString(),
        code: json['code'].toString(),
        displayName: (json['display_name'] ?? '').toString(),
        valueNum: _num(json['value_num']),
        valueText: json['value_text'] as String?,
        unit: json['unit'] as String?,
        valueRaw: _num(json['value_raw']),
        unitRaw: json['unit_raw'] as String?,
        labLow: _num(json['lab_low']),
        labHigh: _num(json['lab_high']),
        refLow: _num(json['ref_low']),
        refHigh: _num(json['ref_high']),
        flag: ObservationFlag.fromValue(json['flag'] as String?),
        effectiveAt:
            _date(json['effective_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        origin: ObservationOrigin.fromValue(json['origin'] as String?),
        documentId: json['document_id']?.toString(),
        extractionId: json['extraction_id']?.toString(),
        confidence: _num(json['confidence']),
        needsReview: json['needs_review'] == true,
        confirmedAt: _date(json['confirmed_at']),
        confirmedBy: json['confirmed_by']?.toString(),
        supersedesId: json['supersedes_id']?.toString(),
        supersededAt: _date(json['superseded_at']),
        catalogVersion: (json['catalog_version'] as num?)?.toInt() ?? 0,
        ruleVersion: (json['rule_version'] ?? 'board-0').toString(),
        labName: json['lab_name'] as String?,
        createdAt: _date(json['created_at']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'subject_id': subjectId,
        'code': code,
        'display_name': displayName,
        'value_num': valueNum,
        'value_text': valueText,
        'unit': unit,
        'value_raw': valueRaw,
        'unit_raw': unitRaw,
        'lab_low': labLow,
        'lab_high': labHigh,
        'ref_low': refLow,
        'ref_high': refHigh,
        'flag': flag.value,
        'effective_at': effectiveAt.toIso8601String(),
        'origin': origin.value,
        'document_id': documentId,
        'extraction_id': extractionId,
        'confidence': confidence,
        'needs_review': needsReview,
        'catalog_version': catalogVersion,
        'rule_version': ruleVersion,
        'lab_name': labName,
      };

  Observation copyWith({
    double? valueNum,
    String? valueText,
    String? unit,
    ObservationFlag? flag,
    DateTime? effectiveAt,
    bool? needsReview,
    DateTime? confirmedAt,
    DateTime? supersededAt,
  }) =>
      Observation(
        id: id,
        subjectId: subjectId,
        code: code,
        displayName: displayName,
        valueNum: valueNum ?? this.valueNum,
        valueText: valueText ?? this.valueText,
        unit: unit ?? this.unit,
        valueRaw: valueRaw,
        unitRaw: unitRaw,
        labLow: labLow,
        labHigh: labHigh,
        refLow: refLow,
        refHigh: refHigh,
        flag: flag ?? this.flag,
        effectiveAt: effectiveAt ?? this.effectiveAt,
        origin: origin,
        documentId: documentId,
        extractionId: extractionId,
        confidence: confidence,
        needsReview: needsReview ?? this.needsReview,
        confirmedAt: confirmedAt ?? this.confirmedAt,
        confirmedBy: confirmedBy,
        supersedesId: supersedesId,
        supersededAt: supersededAt ?? this.supersededAt,
        catalogVersion: catalogVersion,
        ruleVersion: ruleVersion,
        labName: labName,
        createdAt: createdAt,
      );
}

/// Row of `public.extractions`: one attempt at reading a document.
class Extraction {
  const Extraction({
    required this.id,
    required this.documentId,
    required this.subjectId,
    this.status = ExtractionStatus.queued,
    this.attempt = 1,
    this.model,
    this.promptVersion,
    this.detectedCategory,
    this.detectedDate,
    this.labName,
    this.meanConfidence,
    this.tokensIn,
    this.tokensOut,
    this.costMicroUsd,
    this.valuesTotal = 0,
    this.valuesSaved = 0,
    this.valuesToReview = 0,
    this.failureReason,
    this.startedAt,
    this.finishedAt,
    this.createdAt,
  });

  final String id;
  final String documentId;
  final String subjectId;
  final ExtractionStatus status;
  final int attempt;
  final String? model;
  final String? promptVersion;
  final String? detectedCategory;
  final DateTime? detectedDate;
  final String? labName;
  final double? meanConfidence;
  final int? tokensIn;
  final int? tokensOut;

  /// Cost of the run in millionths of a dollar, recorded per document.
  final int? costMicroUsd;
  final int valuesTotal;
  final int valuesSaved;
  final int valuesToReview;
  final String? failureReason;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? createdAt;

  bool get isRunning => status.isRunning;
  bool get hasValuesToReview => valuesToReview > 0;

  /// Cost in dollars, for the operations dashboard.
  double? get costUsd => costMicroUsd == null ? null : costMicroUsd! / 1000000;

  /// Rough progress of the pipeline, for the progress indicator.
  double get progress => switch (status) {
        ExtractionStatus.queued => 0.1,
        ExtractionStatus.classifying => 0.35,
        ExtractionStatus.extracting => 0.7,
        ExtractionStatus.normalizing => 0.9,
        _ => 1,
      };

  factory Extraction.fromJson(Map<String, dynamic> json) => Extraction(
        id: json['id'].toString(),
        documentId: json['document_id'].toString(),
        subjectId: json['subject_id'].toString(),
        status: ExtractionStatus.fromValue(json['status'] as String?),
        attempt: (json['attempt'] as num?)?.toInt() ?? 1,
        model: json['model'] as String?,
        promptVersion: json['prompt_version'] as String?,
        detectedCategory: json['detected_category'] as String?,
        detectedDate: _date(json['detected_date']),
        labName: json['lab_name'] as String?,
        meanConfidence: _num(json['mean_confidence']),
        tokensIn: (json['tokens_in'] as num?)?.toInt(),
        tokensOut: (json['tokens_out'] as num?)?.toInt(),
        costMicroUsd: (json['cost_micro_usd'] as num?)?.toInt(),
        valuesTotal: (json['values_total'] as num?)?.toInt() ?? 0,
        valuesSaved: (json['values_saved'] as num?)?.toInt() ?? 0,
        valuesToReview: (json['values_to_review'] as num?)?.toInt() ?? 0,
        failureReason: json['failure_reason'] as String?,
        startedAt: _date(json['started_at']),
        finishedAt: _date(json['finished_at']),
        createdAt: _date(json['created_at']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'document_id': documentId,
        'subject_id': subjectId,
        'status': status.value,
        'attempt': attempt,
        'model': model,
        'prompt_version': promptVersion,
        'detected_category': detectedCategory,
        'detected_date': detectedDate?.toIso8601String().substring(0, 10),
        'lab_name': labName,
        'mean_confidence': meanConfidence,
        'tokens_in': tokensIn,
        'tokens_out': tokensOut,
        'cost_micro_usd': costMicroUsd,
        'values_total': valuesTotal,
        'values_saved': valuesSaved,
        'values_to_review': valuesToReview,
        'failure_reason': failureReason,
      };

  Extraction copyWith({
    ExtractionStatus? status,
    int? valuesSaved,
    int? valuesToReview,
    String? failureReason,
    DateTime? finishedAt,
  }) =>
      Extraction(
        id: id,
        documentId: documentId,
        subjectId: subjectId,
        status: status ?? this.status,
        attempt: attempt,
        model: model,
        promptVersion: promptVersion,
        detectedCategory: detectedCategory,
        detectedDate: detectedDate,
        labName: labName,
        meanConfidence: meanConfidence,
        tokensIn: tokensIn,
        tokensOut: tokensOut,
        costMicroUsd: costMicroUsd,
        valuesTotal: valuesTotal,
        valuesSaved: valuesSaved ?? this.valuesSaved,
        valuesToReview: valuesToReview ?? this.valuesToReview,
        failureReason: failureReason ?? this.failureReason,
        startedAt: startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        createdAt: createdAt,
      );
}
