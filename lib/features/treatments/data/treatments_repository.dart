import 'package:medical24/features/treatments/data/treatment_models.dart';
import 'package:medical24/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class TreatmentsRepository {
  Future<TreatmentSearchResult> search(TreatmentFilters filters, {int offset = 0, int limit = 20});
  Future<TreatmentFacets> facets(TreatmentFilters filters);
  Future<TreatmentDetail?> detail(String id);
  Future<List<CompareTreatment>> compare(List<String> ids);
  Future<List<TreatmentReview>> reviews(String id, {int offset = 0, int limit = 20});
  Future<List<TreatmentSummary>> featured({int limit = 6});
  Future<List<TreatmentSummary>> favorites();
  Future<bool> toggleFavorite(String id);
  Future<Map<String, dynamic>?> myReview(String id);
  Future<String> submitReview(String id, int rating, Map<String, int> subRatings, String? title, String body);
  Future<void> withdrawReview(String id);
}

class SupabaseTreatmentsRepository implements TreatmentsRepository {
  const SupabaseTreatmentsRepository();
  SupabaseClient get _db => SupabaseConfig.client;
  Map<String, dynamic> _params(TreatmentFilters f) => <String, dynamic>{'p_query': f.query.isEmpty ? null : f.query, 'p_scope': f.scope == null ? null : <String>[f.scope!], 'p_family': f.family == null ? null : <String>[f.family!], 'p_modality': f.modality == null ? null : <String>[f.modality!], 'p_city': f.city, 'p_min_rating': f.minRating, 'p_max_price_cents': null, 'p_duration_bucket': f.duration, 'p_conditions': null, 'p_tags': null};

  @override
  Future<TreatmentSearchResult> search(TreatmentFilters filters, {int offset = 0, int limit = 20}) async {
    final List<dynamic> rows = await _db.rpc('search_treatments', params: <String, dynamic>{..._params(filters), 'p_sort': filters.sort, 'p_limit': limit, 'p_offset': offset}) as List<dynamic>;
    final List<TreatmentSummary> items = rows.map((row) => TreatmentSummary.fromJson(Map<String, dynamic>.from(row as Map))).toList();
    return TreatmentSearchResult(items: items, total: items.isEmpty ? 0 : items.first.totalCount);
  }
  @override
  Future<TreatmentFacets> facets(TreatmentFilters filters) async => TreatmentFacets.fromJson(Map<String, dynamic>.from(await _db.rpc('facets_for_treatments', params: _params(filters)) as Map));
  @override
  Future<TreatmentDetail?> detail(String id) async { final dynamic value = await _db.rpc('treatment_detail', params: <String, dynamic>{'p_id': id}); return value is Map ? TreatmentDetail(Map<String, dynamic>.from(value)) : null; }
  @override
  Future<List<CompareTreatment>> compare(List<String> ids) async => ((await _db.rpc('treatment_compare', params: <String, dynamic>{'p_ids': ids})) as List).map((row) => CompareTreatment(Map<String, dynamic>.from(row as Map))).toList();
  @override
  Future<List<TreatmentReview>> reviews(String id, {int offset = 0, int limit = 20}) async => ((await _db.rpc('reviews_for_target', params: <String, dynamic>{'p_target_type': 'treatment', 'p_target_id': id, 'p_limit': limit, 'p_offset': offset})) as List).map((row) => TreatmentReview(Map<String, dynamic>.from(row as Map))).toList();
  @override
  Future<List<TreatmentSummary>> featured({int limit = 6}) async => ((await _db.rpc('featured_treatments', params: <String, dynamic>{'p_limit': limit})) as List).map((row) => TreatmentSummary.fromJson(Map<String, dynamic>.from(row as Map))).toList();
  @override
  Future<List<TreatmentSummary>> favorites() async {
    final List<dynamic> favoriteRows = await _db.from('favorites').select('target_id').eq('target_type', 'treatment');
    final List<String> ids = favoriteRows.map((row) => (row as Map)['target_id'].toString()).toList();
    if (ids.isEmpty) return const <TreatmentSummary>[];
    final List<dynamic> treatments = await _db.from('treatments').select('id,title,summary,family,scope,evidence_level,price_from_cents,session_minutes,modality,is_demo,facilities(name,city)').inFilter('id', ids);
    final List<dynamic> ratings = await _db.from('rating_summaries').select('target_id,rating_avg,rating_count').eq('target_type', 'treatment').inFilter('target_id', ids);
    final Map<String, Map<String, dynamic>> byId = <String, Map<String, dynamic>>{for (final dynamic row in ratings) (row as Map)['target_id'].toString(): Map<String, dynamic>.from(row)};
    return treatments.map((dynamic raw) { final Map<String, dynamic> row = Map<String, dynamic>.from(raw as Map); final Map<String, dynamic> facility = Map<String, dynamic>.from(row.remove('facilities') as Map? ?? const {}); row.addAll(byId[row['id'].toString()] ?? const {}); row['facility_name'] = facility['name']; row['facility_city'] = facility['city']; return TreatmentSummary.fromJson(row); }).toList();
  }
  @override
  Future<bool> toggleFavorite(String id) async => await _db.rpc('toggle_favorite', params: <String, dynamic>{'p_target_type': 'treatment', 'p_target_id': id}) == true;
  @override
  Future<Map<String, dynamic>?> myReview(String id) async { final String? user = SupabaseConfig.currentUserId; if (user == null) return null; final dynamic row = await _db.from('reviews').select('id,status,rating,sub_ratings,title,body').eq('target_type', 'treatment').eq('target_id', id).eq('author_id', user).neq('status', 'withdrawn').maybeSingle(); return row is Map ? Map<String, dynamic>.from(row) : null; }
  @override
  Future<String> submitReview(String id, int rating, Map<String, int> subRatings, String? title, String body) async => (await _db.rpc('submit_review', params: <String, dynamic>{'p_target_type': 'treatment', 'p_target_id': id, 'p_rating': rating, 'p_sub_ratings': subRatings, 'p_title': title, 'p_body': body})).toString();
  @override
  Future<void> withdrawReview(String id) => _db.rpc('withdraw_review', params: <String, dynamic>{'p_id': id});
}