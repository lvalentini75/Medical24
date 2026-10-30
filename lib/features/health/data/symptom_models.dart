/// One entry in the symptom diary.
class SymptomEntry {
  const SymptomEntry({required this.id, required this.severity, required this.occurredAt, required this.createdAt, this.code, this.freeText, this.notes});

  final String id;
  final String? code;
  final String? freeText;
  final int severity;
  final String? notes;
  final DateTime occurredAt;
  final DateTime createdAt;

  bool editableAt(DateTime now) => now.difference(createdAt.toLocal()) < const Duration(hours: 24);

  factory SymptomEntry.fromJson(Map<String, dynamic> json) => SymptomEntry(id: json['id'].toString(), code: json['code']?.toString(), freeText: json['free_text']?.toString(), severity: (json['severity'] as num?)?.toInt() ?? 1, notes: json['notes']?.toString(), occurredAt: DateTime.parse(json['occurred_at'].toString()).toLocal(), createdAt: DateTime.parse(json['created_at'].toString()).toLocal());
}

class SymptomInput {
  const SymptomInput({this.code, this.freeText, required this.severity, this.notes, required this.occurredAt});
  final String? code;
  final String? freeText;
  final int severity;
  final String? notes;
  final DateTime occurredAt;
}

const List<String> symptomCodes = <String>['headache', 'nausea', 'fatigue', 'dizziness', 'chest_pain', 'shortness_of_breath', 'fever', 'cough', 'abdominal_pain', 'joint_pain', 'back_pain', 'insomnia', 'anxiety', 'palpitations', 'rash', 'swelling', 'diarrhea', 'constipation', 'loss_of_appetite', 'other'];