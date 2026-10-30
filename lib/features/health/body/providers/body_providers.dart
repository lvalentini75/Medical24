import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:medical24/features/health/body/data/body_models.dart';
import 'package:medical24/features/health/body/data/body_repository.dart';

final Provider<BodyRepository> bodyRepositoryProvider = Provider<BodyRepository>((Ref ref) => const SupabaseBodyRepository());
final FutureProvider<List<OrganOverview>> organOverviewProvider = FutureProvider<List<OrganOverview>>((Ref ref) => ref.watch(bodyRepositoryProvider).overview());
final organBiomarkersProvider = FutureProvider.family<List<OrganBiomarker>, String>((Ref ref, String organ) => ref.watch(bodyRepositoryProvider).biomarkers(organ));
final organHistoryProvider = FutureProvider.family<List<OrganHistoryEntry>, String>((Ref ref, String organ) => ref.watch(bodyRepositoryProvider).history(organ));
final organComparisonProvider = FutureProvider.family<OrganComparison, String>((Ref ref, String organ) => ref.watch(bodyRepositoryProvider).comparison(organ));
final organEpisodesProvider = FutureProvider.family<List<OrganEpisode>, String>((Ref ref, String organ) => ref.watch(bodyRepositoryProvider).episodes(organ));
final FutureProvider<OrganRuleVersion?> organRuleProvider = FutureProvider<OrganRuleVersion?>((Ref ref) => ref.watch(bodyRepositoryProvider).activeRule());
final StateProvider<String?> selectedOrganIdProvider = StateProvider<String?>((Ref ref) => null);

class OrganComputeController extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async => null;
  Future<void> refresh() async {
    state = const AsyncLoading<int?>();
    state = await AsyncValue.guard<int?>(() => ref.read(bodyRepositoryProvider).compute());
    if (!state.hasError) {
      ref.invalidate(organOverviewProvider);
      ref.invalidate(organRuleProvider);
    }
  }
}
final AsyncNotifierProvider<OrganComputeController, int?> organComputeProvider = AsyncNotifierProvider<OrganComputeController, int?>(OrganComputeController.new);