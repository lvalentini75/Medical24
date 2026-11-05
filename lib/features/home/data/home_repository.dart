import 'package:medical24/features/home/data/home_models.dart';
import 'package:medical24/supabase/supabase_config.dart';

abstract class HomeRepository {
  Future<HomeSnapshot> snapshot(String subjectId);
}

class SupabaseHomeRepository implements HomeRepository {
  const SupabaseHomeRepository();
  @override
  Future<HomeSnapshot> snapshot(String subjectId) async {
    final dynamic data = await SupabaseConfig.rpc('home_snapshot', params: <String, dynamic>{'p_subject': subjectId});
    return HomeSnapshot.fromJson(Map<String, dynamic>.from(data as Map));
  }
}