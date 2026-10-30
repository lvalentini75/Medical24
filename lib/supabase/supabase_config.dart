import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Supabase configuration and client access for Medical 24.
///
/// The anon key is the only key that may ever live in the client.
/// `service_role` is used exclusively inside Edge Functions.
class SupabaseConfig {
  static const String supabaseUrl = 'https://hiydzmwacuvkdklhhoef.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhpeWR6bXdhY3V2a2RrbGhob2VmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI4Mjk0MzYsImV4cCI6MjEwODQwNTQzNn0.xMupedGE0tEh1jDlsAwMOHFvwkiS_dl2VEOkB-EKXiM';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: anonKey,
      debug: kDebugMode,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  /// Currently authenticated user, or null when signed out.
  static User? get currentUser => auth.currentUser;

  /// Convenience accessor for the authenticated user id (`auth.uid`).
  /// This is also the default `subject_id` when no family member is selected.
  static String? get currentUserId => auth.currentUser?.id;

  static bool get isSignedIn => auth.currentUser != null;

  /// Single source of truth for auth state changes.
  static Stream<AuthState> get onAuthStateChange => auth.onAuthStateChange;

  /// Call a Postgres function (e.g. `can_access_subject`, `resolve_thresholds`).
  static Future<dynamic> rpc(String fn, {Map<String, dynamic>? params}) async {
    try {
      return await client.rpc(fn, params: params);
    } catch (e) {
      debugPrint('Supabase rpc "$fn" failed: $e');
      rethrow;
    }
  }

  /// Short-lived signed URL for a private bucket object.
  /// Clinical files live under `subjects/{subject_id}/...`.
  static Future<String> createSignedUrl(
    String bucket,
    String path, {
    int expiresInSeconds = 600,
  }) async {
    try {
      return await client.storage
          .from(bucket)
          .createSignedUrl(path, expiresInSeconds);
    } catch (e) {
      debugPrint('Supabase signed url failed for $bucket/$path: $e');
      rethrow;
    }
  }
}

/// Error raised by [SupabaseService] with a message safe to show to the user.
/// Never contains clinical data.
class SupabaseServiceException implements Exception {
  const SupabaseServiceException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Generic database service for CRUD operations
class SupabaseService {
  /// Select multiple records from a table
  static Future<List<Map<String, dynamic>>> select(
    String table, {
    String? select,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      // Apply filters
      if (filters != null) {
        for (final entry in filters.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      return await query;
    } catch (e) {
      throw _handleDatabaseError('select', table, e);
    }
  }

  /// Select a single record from a table
  static Future<Map<String, dynamic>?> selectSingle(
    String table, {
    String? select,
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      return await query.maybeSingle();
    } catch (e) {
      throw _handleDatabaseError('selectSingle', table, e);
    }
  }

  /// Insert a record into a table
  static Future<List<Map<String, dynamic>>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    try {
      return await SupabaseConfig.client.from(table).insert(data).select();
    } catch (e) {
      throw _handleDatabaseError('insert', table, e);
    }
  }

  /// Insert multiple records into a table
  static Future<List<Map<String, dynamic>>> insertMultiple(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      return await SupabaseConfig.client.from(table).insert(data).select();
    } catch (e) {
      throw _handleDatabaseError('insertMultiple', table, e);
    }
  }

  /// Update records in a table
  static Future<List<Map<String, dynamic>>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).update(data);

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      return await query.select();
    } catch (e) {
      throw _handleDatabaseError('update', table, e);
    }
  }

  /// Delete records from a table
  static Future<void> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).delete();

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      await query;
    } catch (e) {
      throw _handleDatabaseError('delete', table, e);
    }
  }

  /// Get direct table reference for complex queries
  static SupabaseQueryBuilder from(String table) =>
      SupabaseConfig.client.from(table);

  /// Realtime stream of rows for a table, ordered by [orderBy].
  /// [primaryKey] must match the table primary key columns.
  static Stream<List<Map<String, dynamic>>> stream(
    String table, {
    List<String> primaryKey = const ['id'],
    String? filterColumn,
    Object? filterValue,
    String? orderBy,
    bool ascending = false,
    int? limit,
  }) {
    dynamic query =
        SupabaseConfig.client.from(table).stream(primaryKey: primaryKey);
    if (filterColumn != null) query = query.eq(filterColumn, filterValue);
    if (orderBy != null) query = query.order(orderBy, ascending: ascending);
    if (limit != null) query = query.limit(limit);
    return (query as Stream).cast<List<Map<String, dynamic>>>();
  }

  /// Insert or update a record based on the table conflict target.
  static Future<List<Map<String, dynamic>>> upsert(
    String table,
    Map<String, dynamic> data, {
    String? onConflict,
  }) async {
    try {
      return await SupabaseConfig.client
          .from(table)
          .upsert(data, onConflict: onConflict)
          .select();
    } catch (e) {
      throw _handleDatabaseError('upsert', table, e);
    }
  }

  /// Handle database errors.
  /// Returns a neutral, user-readable error without clinical details.
  static SupabaseServiceException _handleDatabaseError(
    String operation,
    String table,
    dynamic error,
  ) {
    debugPrint('Supabase $operation on $table failed: $error');
    if (error is PostgrestException) {
      return SupabaseServiceException(
        'Failed to $operation from $table: ${error.message}',
        code: error.code,
      );
    }
    return SupabaseServiceException('Failed to $operation from $table.');
  }
}
