import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/features/home/data/home_models.dart';
import 'package:medical24/supabase/supabase_config.dart';

abstract class HomeRepository {
  Future<HomeSnapshot> snapshot();
}

class SupabaseHomeRepository implements HomeRepository {
  const SupabaseHomeRepository();
  @override
  Future<HomeSnapshot> snapshot() async {
    final String subject = SupabaseConfig.currentUserId ?? (throw AppFailure.unauthorized);
    final dynamic data = await SupabaseConfig.rpc('home_snapshot', params: <String, dynamic>{'p_subject': subject});
    return HomeSnapshot.fromJson(Map<String, dynamic>.from(data as Map));
  }
}