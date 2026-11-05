import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:medical24/supabase/supabase_config.dart';

/// Last known state of a GDPR data export.
class DataExportState {
  const DataExportState({required this.status, this.exportId, this.requestedAt, this.expiresAt, this.bytes, this.fileCount, this.truncated = false, this.errorCode, this.url});

  final String status;
  final String? exportId;
  final DateTime? requestedAt;
  final DateTime? expiresAt;
  final int? bytes;
  final int? fileCount;
  final bool truncated;
  final String? errorCode;
  final String? url;

  factory DataExportState.fromJson(Map<String, dynamic> json) => DataExportState(
    status: (json['status'] ?? (json['url'] == null ? 'pending' : 'ready')).toString(),
    exportId: json['export_id']?.toString(),
    requestedAt: DateTime.tryParse(json['requested_at']?.toString() ?? ''),
    expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
    bytes: _asInt(json['bytes']),
    fileCount: _asInt(json['file_count']),
    truncated: json['truncated'] == true,
    errorCode: json['error_code']?.toString(),
    url: json['url']?.toString(),
  );

  static int? _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}

/// Result returned after closing an account.
class DeleteAccountResult {
  const DeleteAccountResult({required this.purgeAt, required this.filesRemoved});

  final DateTime purgeAt;
  final int filesRemoved;
}

/// Neutral Edge Function error used by settings UI and widget tests.
class SettingsPrivacyException implements Exception {
  const SettingsPrivacyException({required this.status, required this.code});

  final int status;
  final String code;
}

/// Contract for privacy operations, injectable in widget tests.
abstract interface class SettingsPrivacyRepository {
  Future<DataExportState?> latestExport();
  Future<DataExportState> requestExport();
  Future<DeleteAccountResult> deleteAccount();
}

typedef SettingsFunctionInvoker = Future<Map<String, dynamic>> Function(String function, Map<String, dynamic> body);

/// Supabase implementation. Both operations run only through authenticated Edge Functions.
class SupabaseSettingsPrivacyRepository implements SettingsPrivacyRepository {
  const SupabaseSettingsPrivacyRepository({this.invoker});

  final SettingsFunctionInvoker? invoker;

  SupabaseClient get _client => SupabaseConfig.client;

  @override
  Future<DataExportState?> latestExport() async {
    final Map<String, dynamic> json = await _invoke('export-data', <String, dynamic>{'action': 'latest'});
    if (json['export'] == null && !json.containsKey('status')) return null;
    return DataExportState.fromJson(json);
  }

  @override
  Future<DataExportState> requestExport() async {
    final Map<String, dynamic> json = await _invoke('export-data', <String, dynamic>{});
    return DataExportState.fromJson(json);
  }

  @override
  Future<DeleteAccountResult> deleteAccount() async {
    final Map<String, dynamic> json = await _invoke('delete-account', <String, dynamic>{'confirm': 'DELETE'});
    final DateTime? purgeAt = DateTime.tryParse(json['purge_at']?.toString() ?? '');
    if (json['deleted'] != true || purgeAt == null) throw const SettingsPrivacyException(status: 500, code: 'invalid_response');
    return DeleteAccountResult(purgeAt: purgeAt, filesRemoved: DataExportState._asInt(json['files_removed']) ?? 0);
  }

  Future<Map<String, dynamic>> _invoke(String function, Map<String, dynamic> body) async {
    if (invoker != null) return invoker!(function, body);
    try {
      final FunctionResponse response = await _client.functions.invoke(function, body: body);
      if (response.data is! Map) throw const SettingsPrivacyException(status: 500, code: 'invalid_response');
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      final dynamic details = error.details;
      final String code = details is Map ? (details['code'] ?? 'server_error').toString() : 'server_error';
      throw SettingsPrivacyException(status: error.status, code: code);
    }
  }
}