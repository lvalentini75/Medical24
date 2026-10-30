import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/consent_record.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/utils/app_logger.dart';
import '../../../supabase/supabase_config.dart';

/// Reads and writes `profiles`, `consents` and `audit_log` through RLS.
/// No access filter is written here: the policies decide.
class ProfileRepository {
  const ProfileRepository();

  SupabaseClient get _db => SupabaseConfig.client;

  Future<UserProfile?> fetchMyProfile() async {
    final String? uid = SupabaseConfig.currentUserId;
    if (uid == null) return null;
    try {
      final Map<String, dynamic>? row =
          await _db.from('profiles').select().eq('id', uid).maybeSingle();
      if (row == null) return null;
      return UserProfile.fromJson(row);
    } catch (e) {
      throw AppFailure.from(e, where: 'profile.fetchMyProfile');
    }
  }

  Future<UserProfile> upsertMyProfile(Map<String, dynamic> values) async {
    final String? uid = SupabaseConfig.currentUserId;
    if (uid == null) throw AppFailure.unauthorized;
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        ...values,
        'id': uid,
      };
      final Map<String, dynamic> row = await _db
          .from('profiles')
          .upsert(payload, onConflict: 'id')
          .select()
          .single();
      AppLogger.event('profile_updated');
      return UserProfile.fromJson(row);
    } catch (e) {
      throw AppFailure.from(e, where: 'profile.upsertMyProfile');
    }
  }

  Future<UserProfile> completeOnboarding(Map<String, dynamic> values) async {
    final UserProfile profile = await upsertMyProfile(<String, dynamic>{
      ...values,
      'onboarded_at': DateTime.now().toUtc().toIso8601String(),
    });
    await logAudit('onboarding_completed', targetTable: 'profiles');
    return profile;
  }

  Future<List<ConsentRecord>> fetchMyConsents() async {
    final String? uid = SupabaseConfig.currentUserId;
    if (uid == null) return const <ConsentRecord>[];
    try {
      final List<dynamic> rows = await _db
          .from('consents')
          .select()
          .eq('user_id', uid)
          .order('granted_at', ascending: false);
      return rows
          .map((dynamic r) =>
              ConsentRecord.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      throw AppFailure.from(e, where: 'profile.fetchMyConsents');
    }
  }

  /// Append-only consent write through the security definer function.
  Future<void> recordConsent({
    required ConsentType type,
    required String version,
    required bool granted,
    String locale = 'it',
  }) async {
    try {
      await _db.rpc('record_consent', params: <String, dynamic>{
        'consent_type': type.value,
        'consent_version': version,
        'is_granted': granted,
        'consent_locale': locale,
      });
      AppLogger.event('consent_recorded', meta: <String, Object?>{
        'type': type.value,
        'granted': granted,
      });
    } catch (e) {
      throw AppFailure.from(e, where: 'profile.recordConsent');
    }
  }

  /// Latest state per consent type.
  Future<Map<ConsentType, bool>> latestConsentState() async {
    final List<ConsentRecord> all = await fetchMyConsents();
    final Map<ConsentType, bool> state = <ConsentType, bool>{};
    for (final ConsentRecord c in all) {
      state.putIfAbsent(c.type, () => c.granted);
    }
    return state;
  }

  Future<void> logAudit(
    String action, {
    String? targetTable,
    String? targetId,
    String? subjectId,
  }) async {
    try {
      await _db.rpc('log_audit', params: <String, dynamic>{
        'action': action,
        'target_table': targetTable,
        'target_id': targetId,
        'subject_id': subjectId,
        'device': null,
      });
    } catch (e) {
      // Audit must never block the user flow; the code only is logged.
      AppLogger.error('profile.logAudit', e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyAuditLog({int limit = 100}) async {
    final String? uid = SupabaseConfig.currentUserId;
    if (uid == null) return const <Map<String, dynamic>>[];
    try {
      final List<dynamic> rows = await _db
          .from('audit_log')
          .select()
          .eq('subject_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map((dynamic r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (e) {
      throw AppFailure.from(e, where: 'profile.fetchMyAuditLog');
    }
  }

  /// Soft delete now + scheduled purge after 30 days (Edge Function).
  Future<void> deleteAccount() async {
    try {
      await _db.functions.invoke('delete-account');
      AppLogger.event('account_delete_requested');
    } catch (e) {
      // Fallback on the SQL function if the Edge Function is not deployed yet.
      try {
        await _db.rpc('soft_delete_account');
        AppLogger.event('account_soft_deleted_fallback');
      } catch (inner) {
        throw AppFailure.from(inner, where: 'profile.deleteAccount');
      }
    }
  }
}
