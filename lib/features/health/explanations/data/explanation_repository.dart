import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:medical24/supabase/supabase_config.dart';

enum ExplanationTargetType { biomarker, organ, risk, document }

enum ExplanationLevel { simple, clinical }

enum ExplanationRefusal { filter, limit }

class ExplanationRequest {
  const ExplanationRequest({required this.subjectId, required this.targetType, required this.targetId, required this.level, required this.lang});
  final String subjectId;
  final ExplanationTargetType targetType;
  final String targetId;
  final ExplanationLevel level;
  final String lang;
}

class ExplanationResult {
  const ExplanationResult({required this.text, required this.level, required this.lang, required this.cached, required this.generatedAt, required this.model});
  final String text;
  final ExplanationLevel level;
  final String lang;
  final bool cached;
  final DateTime generatedAt;
  final String model;

  factory ExplanationResult.fromFunction(Map<String, dynamic> json) => ExplanationResult(
    text: (json['text'] ?? '').toString(),
    level: ExplanationLevel.values.byName((json['level'] ?? 'simple').toString()),
    lang: (json['lang'] ?? 'it').toString(),
    cached: json['cached'] == true,
    generatedAt: DateTime.tryParse((json['generated_at'] ?? '').toString()) ?? DateTime.now(),
    model: (json['model'] ?? '').toString(),
  );

  factory ExplanationResult.fromCache(Map<String, dynamic> json) => ExplanationResult(
    text: (json['explanation_text'] ?? '').toString(),
    level: ExplanationLevel.values.byName((json['explanation_level'] ?? 'simple').toString()),
    lang: (json['explanation_lang'] ?? 'it').toString(),
    cached: true,
    generatedAt: DateTime.tryParse((json['generated_at'] ?? '').toString()) ?? DateTime.now(),
    model: (json['model'] ?? '').toString(),
  );
}

class ExplanationUsage {
  const ExplanationUsage({required this.used, required this.maxPerDay});
  final int used;
  final int maxPerDay;
  int get remaining => (maxPerDay - used).clamp(0, maxPerDay);
}

class ExplanationRefused implements Exception {
  const ExplanationRefused(this.reason);
  final ExplanationRefusal reason;
}

abstract interface class ExplanationRepository {
  Future<ExplanationLevel> readPreferredLevel();
  Future<void> savePreferredLevel(ExplanationLevel level);
  Future<ExplanationUsage> usage(String subjectId);
  Future<ExplanationResult?> lookup(ExplanationRequest request);
  Future<ExplanationResult> generate(ExplanationRequest request, {bool force = false});
}

class SupabaseExplanationRepository implements ExplanationRepository {
  const SupabaseExplanationRepository();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _levelKey = 'explanation_level';

  SupabaseClient get _db => SupabaseConfig.client;

  @override
  Future<ExplanationLevel> readPreferredLevel() async {
    final String? value = await _storage.read(key: _levelKey);
    return value == ExplanationLevel.clinical.name ? ExplanationLevel.clinical : ExplanationLevel.simple;
  }

  @override
  Future<void> savePreferredLevel(ExplanationLevel level) => _storage.write(key: _levelKey, value: level.name);

  @override
  Future<ExplanationUsage> usage(String subjectId) async {
    final dynamic data = await _db.rpc('explanation_usage', params: <String, dynamic>{'p_subject': subjectId});
    final Map<String, dynamic>? row = _row(data);
    return ExplanationUsage(used: (row?['used'] as num?)?.toInt() ?? 0, maxPerDay: (row?['max_per_day'] as num?)?.toInt() ?? 30);
  }

  @override
  Future<ExplanationResult?> lookup(ExplanationRequest request) async {
    final dynamic context = await _db.rpc('explanation_context', params: <String, dynamic>{'p_subject': request.subjectId, 'p_target_type': request.targetType.name, 'p_target_id': request.targetId});
    final String hash = (context is Map ? context['inputs_hash'] : null)?.toString() ?? '';
    if (hash.isEmpty) return null;
    final dynamic data = await _db.rpc('explanation_lookup', params: <String, dynamic>{'p_subject': request.subjectId, 'p_target_type': request.targetType.name, 'p_target_id': request.targetId, 'p_level': request.level.name, 'p_lang': request.lang, 'p_inputs_hash': hash});
    final Map<String, dynamic>? row = _row(data);
    return row == null ? null : ExplanationResult.fromCache(row);
  }

  @override
  Future<ExplanationResult> generate(ExplanationRequest request, {bool force = false}) async {
    try {
      final FunctionResponse response = await _db.functions.invoke('explain', body: <String, dynamic>{'subject_id': request.subjectId, 'target_type': request.targetType.name, 'target_id': request.targetId, 'level': request.level.name, 'lang': request.lang, if (force) 'force': true});
      return _parseFunctionBody(response.data);
    } on FunctionException catch (error) {
      final dynamic details = error.details;
      if (details is Map) return _parseFunctionBody(Map<String, dynamic>.from(details));
      rethrow;
    }
  }

  ExplanationResult _parseFunctionBody(dynamic body) {
    if (body is! Map) throw const FormatException('Invalid explain response');
    final Map<String, dynamic> json = Map<String, dynamic>.from(body);
    if (json['refused'] == true) {
      throw ExplanationRefused(json['reason'] == 'limit' ? ExplanationRefusal.limit : ExplanationRefusal.filter);
    }
    if ((json['text'] ?? '').toString().isEmpty) throw const FormatException('Missing explanation text');
    return ExplanationResult.fromFunction(json);
  }

  Map<String, dynamic>? _row(dynamic data) {
    if (data is List && data.isNotEmpty && data.first is Map) return Map<String, dynamic>.from(data.first as Map);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}