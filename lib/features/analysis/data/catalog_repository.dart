import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/biomarker.dart';
import '../../../supabase/supabase_config.dart';

/// Single entry point to `public.biomarker_catalog` and to the board
/// reference functions. No access filter is written here: the catalog is
/// institutional content, readable by everyone, writable only by the board.
class CatalogRepository {
  const CatalogRepository();

  static const String _table = 'biomarker_catalog';

  SupabaseClient get _db => SupabaseConfig.client;

  /// Whole catalog, ordered by category then name.
  Future<List<Biomarker>> fetchAll() async {
    try {
      final List<Map<String, dynamic>> rows =
          await _db.from(_table).select().order('category').order('name_it');
      return rows
          .map((Map<String, dynamic> r) => Biomarker.fromJson(r))
          .toList(growable: false);
    } catch (e) {
      throw AppFailure.from(e, where: 'catalog.fetchAll');
    }
  }

  /// One biomarker by LOINC code.
  Future<Biomarker?> fetchByCode(String code) async {
    try {
      final Map<String, dynamic>? row =
          await _db.from(_table).select().eq('code', code).maybeSingle();
      return row == null ? null : Biomarker.fromJson(row);
    } catch (e) {
      throw AppFailure.from(e, where: 'catalog.fetchByCode');
    }
  }

  /// Several biomarkers at once, keyed by code. Used to decorate a list of
  /// observations without one query per row.
  Future<Map<String, Biomarker>> fetchByCodes(Iterable<String> codes) async {
    final List<String> list = codes.toSet().toList(growable: false);
    if (list.isEmpty) return const <String, Biomarker>{};
    try {
      final List<Map<String, dynamic>> rows =
          await _db.from(_table).select().inFilter('code', list);
      return <String, Biomarker>{
        for (final Map<String, dynamic> r in rows)
          r['code'].toString(): Biomarker.fromJson(r),
      };
    } catch (e) {
      throw AppFailure.from(e, where: 'catalog.fetchByCodes');
    }
  }

  /// Full-text-ish search on names and synonyms, done in Postgres.
  Future<List<Biomarker>> search(String query, {int limit = 30}) async {
    final String term = query.trim();
    if (term.isEmpty) return const <Biomarker>[];
    try {
      final List<Map<String, dynamic>> rows = await _db
          .from(_table)
          .select()
          .or('name_it.ilike.%$term%,name_en.ilike.%$term%,code.ilike.%$term%')
          .order('name_it')
          .limit(limit);
      return rows
          .map((Map<String, dynamic> r) => Biomarker.fromJson(r))
          .toList(growable: false);
    } catch (e) {
      throw AppFailure.from(e, where: 'catalog.search');
    }
  }

  /// Biomarkers linked to one of the 12 body areas.
  Future<List<Biomarker>> fetchByOrgan(String organ) async {
    try {
      final List<Map<String, dynamic>> rows = await _db
          .from(_table)
          .select()
          .contains('organs', <String>[organ]).order('name_it');
      return rows
          .map((Map<String, dynamic> r) => Biomarker.fromJson(r))
          .toList(growable: false);
    } catch (e) {
      throw AppFailure.from(e, where: 'catalog.fetchByOrgan');
    }
  }

  /// Distinct categories, for the filter chips.
  Future<List<String>> categories() async {
    try {
      final List<Map<String, dynamic>> rows =
          await _db.from(_table).select('category').order('category');
      return rows
          .map((Map<String, dynamic> r) => r['category'].toString())
          .toSet()
          .toList(growable: false);
    } catch (e) {
      throw AppFailure.from(e, where: 'catalog.categories');
    }
  }

  /// Institutional range for a subject, resolved by `resolve_reference`.
  /// Never computed on the client: the rule lives in Postgres.
  Future<ReferenceRange?> resolveReference({
    required String subjectId,
    required String code,
  }) async {
    try {
      final dynamic data = await SupabaseConfig.rpc('resolve_reference',
          params: <String, dynamic>{
            'p_subject_id': subjectId,
            'p_code': code,
          });
      final Map<String, dynamic>? row = data is List
          ? (data.isEmpty ? null : Map<String, dynamic>.from(data.first as Map))
          : (data is Map ? Map<String, dynamic>.from(data) : null);
      return row == null ? null : ReferenceRange.fromJson(row);
    } catch (e) {
      throw AppFailure.from(e, where: 'catalog.resolveReference');
    }
  }

  /// Converts a read value to the canonical unit through `normalize_unit`.
  Future<({double? value, String? unit})> normalizeUnit({
    required String code,
    required double value,
    String? unit,
  }) async {
    try {
      final dynamic data =
          await SupabaseConfig.rpc('normalize_unit', params: <String, dynamic>{
        'p_code': code,
        'p_value': value,
        'p_unit': unit,
      });
      final Map<String, dynamic>? row = data is List
          ? (data.isEmpty ? null : Map<String, dynamic>.from(data.first as Map))
          : (data is Map ? Map<String, dynamic>.from(data) : null);
      if (row == null) return (value: value, unit: unit);
      return (
        value: double.tryParse(row['value_num'].toString()),
        unit: row['unit'] as String?,
      );
    } catch (e) {
      throw AppFailure.from(e, where: 'catalog.normalizeUnit');
    }
  }
}
