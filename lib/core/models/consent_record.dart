/// Consent types stored in `public.consents` (enum `consent_type`).
enum ConsentType {
  healthData('health_data'),
  aiProcessing('ai_processing'),
  marketing('marketing'),
  sharing('sharing'),
  research('research'),
  nutritionDiary('nutrition_diary'),
  authoredContent('authored_content');

  const ConsentType(this.value);
  final String value;

  static ConsentType fromValue(String value) => ConsentType.values.firstWhere(
        (ConsentType t) => t.value == value,
        orElse: () => ConsentType.healthData,
      );
}

/// Append-only consent row. Versioned text, never updated nor deleted.
class ConsentRecord {
  const ConsentRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.version,
    required this.granted,
    required this.grantedAt,
    this.revokedAt,
    this.locale = 'it',
  });

  final String id;
  final String userId;
  final ConsentType type;
  final String version;
  final bool granted;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final String locale;

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => ConsentRecord(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        type: ConsentType.fromValue(json['type'] as String),
        version: json['version'] as String,
        granted: json['granted'] as bool? ?? true,
        grantedAt: DateTime.parse(json['granted_at'] as String),
        revokedAt: json['revoked_at'] == null
            ? null
            : DateTime.tryParse(json['revoked_at'] as String),
        locale: (json['locale'] as String?) ?? 'it',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'type': type.value,
        'version': version,
        'granted': granted,
        'granted_at': grantedAt.toIso8601String(),
        'revoked_at': revokedAt?.toIso8601String(),
        'locale': locale,
      };
}

/// Versions of the consent texts shown in onboarding.
/// A change of text requires a new version here.
class ConsentVersions {
  const ConsentVersions._();

  static const String healthData = '2026-10-24.1';
  static const String aiProcessing = '2026-10-24.1';
  static const String marketing = '2026-10-24.1';
}
