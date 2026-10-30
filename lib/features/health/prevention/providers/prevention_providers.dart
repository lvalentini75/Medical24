import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical24/features/health/prevention/data/prevention_models.dart';
import 'package:medical24/features/health/prevention/data/prevention_repository.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/features/home/providers/home_providers.dart';

final Provider<PreventionRepository> preventionRepositoryProvider = Provider<PreventionRepository>((Ref ref) => const SupabasePreventionRepository());
final FutureProvider<PreventionSnapshot> preventionSnapshotProvider = FutureProvider<PreventionSnapshot>((Ref ref) async {
  try {
    return await ref.watch(preventionRepositoryProvider).load();
  } catch (error, stack) {
    debugPrint('preventionSnapshotProvider failed: $error\n$stack');
    rethrow;
  }
});

class PreventionActions {
  const PreventionActions(this.ref);
  final Ref ref;
  Future<bool> saveAnswers(Map<String, dynamic> answers, String version, double weightKg) async {
    await ref.read(preventionRepositoryProvider).saveAnswers(answers, version);
    bool weightSaved = true;
    try {
      await ref.read(healthRepositoryProvider).insertManualValues(<ManualObservationInput>[ManualObservationInput(code: '29463-7', value: weightKg, unit: 'kg')], DateTime.now());
    } catch (_) {
      weightSaved = false;
    }
    ref.invalidate(preventionSnapshotProvider);
    ref.invalidate(homeSnapshotProvider);
    ref.invalidate(healthCatalogProvider);
    ref.invalidate(healthHistoryProvider);
    return weightSaved;
  }
  Future<void> complete(String id, {String? documentId}) async { await ref.read(preventionRepositoryProvider).completeRecommendation(id, documentId: documentId); ref.invalidate(preventionSnapshotProvider); }
  Future<void> dismiss(String id, {String? reason}) async { await ref.read(preventionRepositoryProvider).dismissRecommendation(id, reason: reason); ref.invalidate(preventionSnapshotProvider); }
  Future<void> reopen(String id) async { await ref.read(preventionRepositoryProvider).reopenRecommendation(id); ref.invalidate(preventionSnapshotProvider); }
}

final Provider<PreventionActions> preventionActionsProvider = Provider<PreventionActions>((Ref ref) => PreventionActions(ref));