class DoctorShareLink {
  const DoctorShareLink({required this.id, required this.code, required this.expiresAt, required this.maxOpens, required this.opensCount, required this.status, required this.opens, this.snapshotId, this.lastOpenedAt});

  factory DoctorShareLink.fromJson(Map<String, dynamic> json) => DoctorShareLink(
    id: json['id'].toString(), code: json['code'].toString(), expiresAt: DateTime.parse(json['expires_at'].toString()), maxOpens: (json['max_opens'] as num).toInt(), opensCount: (json['opens_count'] as num?)?.toInt() ?? 0, status: json['status']?.toString() ?? 'active', snapshotId: json['snapshot_id']?.toString(), lastOpenedAt: json['last_opened_at'] == null ? null : DateTime.tryParse(json['last_opened_at'].toString()),
    opens: (json['opens'] as List? ?? const <dynamic>[]).whereType<Map>().map((value) => DoctorLinkOpen.fromJson(Map<String, dynamic>.from(value))).toList(growable: false),
  );

  final String id, code, status;
  final String? snapshotId;
  final DateTime expiresAt;
  final DateTime? lastOpenedAt;
  final int maxOpens, opensCount;
  final List<DoctorLinkOpen> opens;
  int get opensLeft => (maxOpens - opensCount).clamp(0, maxOpens).toInt();
}

class DoctorLinkOpen {
  const DoctorLinkOpen({required this.openedAt, required this.outcome});
  factory DoctorLinkOpen.fromJson(Map<String, dynamic> json) => DoctorLinkOpen(openedAt: DateTime.parse(json['opened_at'].toString()), outcome: json['outcome'].toString());
  final DateTime openedAt;
  final String outcome;
}

class DoctorDossier {
  const DoctorDossier({required this.id, required this.generatedAt, required this.payload, required this.ruleVersions, this.pdfPath});
  factory DoctorDossier.fromJson(Map<String, dynamic> json) => DoctorDossier(id: json['id'].toString(), generatedAt: DateTime.parse(json['generated_at'].toString()), payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const <String, dynamic>{}), ruleVersions: Map<String, dynamic>.from(json['rule_versions'] as Map? ?? const <String, dynamic>{}), pdfPath: json['pdf_path']?.toString());
  final String id;
  final DateTime generatedAt;
  final Map<String, dynamic> payload, ruleVersions;
  final String? pdfPath;
}

class DoctorShareScope {
  const DoctorShareScope({required this.all, this.organs = const <String>[], this.categories = const <String>[], this.from, this.to});
  final bool all;
  final List<String> organs, categories;
  final DateTime? from, to;
  Map<String, dynamic> toJson() => all ? <String, dynamic>{'all': true} : <String, dynamic>{if (organs.isNotEmpty) 'organs': organs, if (categories.isNotEmpty) 'categories': categories, if (from != null) 'from': _date(from!), if (to != null) 'to': _date(to!)};
  static String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

enum DoctorQuestionStatus { draft, sent, answered, closed }

class DoctorQuestion {
  const DoctorQuestion({required this.id, required this.title, required this.body, required this.status, required this.createdAt, required this.updatedAt, this.shareLinkId, this.doctorEmail, this.answer, this.answeredAt, this.answeredVia});

  factory DoctorQuestion.fromJson(Map<String, dynamic> json) => DoctorQuestion(
    id: json['id'].toString(), title: json['title'].toString(), body: json['body'].toString(), status: DoctorQuestionStatus.values.byName(json['status'].toString()), createdAt: DateTime.parse(json['created_at'].toString()), updatedAt: DateTime.parse(json['updated_at'].toString()), shareLinkId: json['share_link_id']?.toString(), doctorEmail: json['doctor_email']?.toString(), answer: json['answer']?.toString(), answeredAt: json['answered_at'] == null ? null : DateTime.tryParse(json['answered_at'].toString()), answeredVia: json['answered_via']?.toString());

  final String id, title, body;
  final DoctorQuestionStatus status;
  final DateTime createdAt, updatedAt;
  final String? shareLinkId, doctorEmail, answer, answeredVia;
  final DateTime? answeredAt;
}

class EmergencyContact {
  const EmergencyContact({required this.name, required this.phone, required this.relationship});
  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(name: json['name']?.toString() ?? '', phone: json['phone']?.toString() ?? '', relationship: json['relation']?.toString() ?? '');
  final String name, phone, relationship;
  Map<String, dynamic> toJson() => <String, dynamic>{'name': name, 'phone': phone, if (relationship.isNotEmpty) 'relation': relationship};
}

class EmergencyCard {
  const EmergencyCard({required this.subjectId, required this.allergies, required this.medications, required this.conditions, required this.contacts, required this.fieldsPublic, required this.publicToken, this.bloodGroup, this.notes});
  factory EmergencyCard.fromJson(Map<String, dynamic> json) => EmergencyCard(subjectId: json['subject_id'].toString(), bloodGroup: json['blood_group']?.toString(), allergies: _strings(json['allergies']), medications: _strings(json['medications']), conditions: _strings(json['conditions']), contacts: (json['contacts'] as List? ?? const <dynamic>[]).whereType<Map>().map((item) => EmergencyContact.fromJson(Map<String, dynamic>.from(item))).toList(growable: false), notes: json['notes']?.toString(), fieldsPublic: Map<String, dynamic>.from(json['fields_public'] as Map? ?? const <String, dynamic>{}).map((key, value) => MapEntry(key, value == true)), publicToken: json['public_token'].toString());
  final String subjectId, publicToken;
  final String? bloodGroup, notes;
  final List<String> allergies, medications, conditions;
  final List<EmergencyContact> contacts;
  final Map<String, bool> fieldsPublic;
  static List<String> _strings(dynamic value) => (value as List? ?? const <dynamic>[]).map((item) => item.toString()).toList(growable: false);
}