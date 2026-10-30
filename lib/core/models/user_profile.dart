/// Row of `public.profiles`. The only sensitive fields in P00 are
/// [birthDate] and [gender].
class UserProfile {
  const UserProfile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.birthDate,
    this.gender,
    this.language = 'it',
    this.units = 'mg_dl',
    this.country,
    this.dataRegion = 'eu',
    this.timezone = 'Europe/Rome',
    this.onboardedAt,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? fullName;
  final String? avatarUrl;
  final DateTime? birthDate;
  final String? gender;
  final String language;
  final String units;
  final String? country;
  final String dataRegion;
  final String timezone;
  final DateTime? onboardedAt;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOnboarded => onboardedAt != null;
  bool get isDeleted => deletedAt != null;

  /// Share of the P00 profile fields that are filled in.
  int get completionPercent {
    final List<bool> fields = <bool>[
      (fullName ?? '').trim().isNotEmpty,
      birthDate != null,
      (gender ?? '').isNotEmpty,
      (country ?? '').isNotEmpty,
      true, // language always set
      true, // units always set
    ];
    final int done = fields.where((bool f) => f).length;
    return ((done / fields.length) * 100).round();
  }

  String? get firstName {
    final String name = (fullName ?? '').trim();
    if (name.isEmpty) return null;
    return name.split(RegExp(r'\s+')).first;
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        fullName: json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        birthDate: _date(json['birth_date']),
        gender: json['gender'] as String?,
        language: (json['language'] as String?) ?? 'it',
        units: (json['units'] as String?) ?? 'mg_dl',
        country: json['country'] as String?,
        dataRegion: (json['data_region'] as String?) ?? 'eu',
        timezone: (json['timezone'] as String?) ?? 'Europe/Rome',
        onboardedAt: _date(json['onboarded_at']),
        deletedAt: _date(json['deleted_at']),
        createdAt: _date(json['created_at']),
        updatedAt: _date(json['updated_at']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'birth_date': birthDate?.toIso8601String().split('T').first,
        'gender': gender,
        'language': language,
        'units': units,
        'country': country,
        'data_region': dataRegion,
        'timezone': timezone,
        'onboarded_at': onboardedAt?.toIso8601String(),
      };

  UserProfile copyWith({
    String? fullName,
    String? avatarUrl,
    DateTime? birthDate,
    String? gender,
    String? language,
    String? units,
    String? country,
    String? dataRegion,
    String? timezone,
    DateTime? onboardedAt,
    DateTime? deletedAt,
  }) =>
      UserProfile(
        id: id,
        fullName: fullName ?? this.fullName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        birthDate: birthDate ?? this.birthDate,
        gender: gender ?? this.gender,
        language: language ?? this.language,
        units: units ?? this.units,
        country: country ?? this.country,
        dataRegion: dataRegion ?? this.dataRegion,
        timezone: timezone ?? this.timezone,
        onboardedAt: onboardedAt ?? this.onboardedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
