import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/data/health_repository.dart';
import 'package:medical24/features/health/data/alert_models.dart';
import 'package:medical24/features/health/data/alerts_repository.dart';
import 'package:medical24/features/health/data/symptom_models.dart';
import 'package:medical24/features/health/data/symptoms_repository.dart';

final Provider<HealthRepository> healthRepositoryProvider = Provider<HealthRepository>((Ref ref) => const SupabaseHealthRepository());

final FutureProvider<List<BiomarkerSummary>> healthCatalogProvider = FutureProvider<List<BiomarkerSummary>>((Ref ref) => ref.watch(healthRepositoryProvider).catalog());

final FutureProvider<List<ManualBiomarker>> manualBiomarkerCatalogProvider = FutureProvider<List<ManualBiomarker>>((Ref ref) => ref.watch(healthRepositoryProvider).manualCatalog());

class HistoryRequest {
  const HistoryRequest(this.code, this.period);
  final String code;
  final HealthPeriod period;
  @override
  bool operator ==(Object other) => other is HistoryRequest && other.code == code && other.period == period;
  @override
  int get hashCode => Object.hash(code, period);
}

final healthHistoryProvider = FutureProvider.family<BiomarkerHistoryData, HistoryRequest>((Ref ref, HistoryRequest request) {
  final DateTime now = DateTime.now();
  return ref.watch(healthRepositoryProvider).history(request.code, from: request.period.from(now), to: now);
});

class HealthWatchController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}
  Future<void> toggleWatch(BiomarkerSummary biomarker, {bool? favorite, bool? tracked}) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard<void>(() => ref.read(healthRepositoryProvider).setWatch(biomarker, favorite: favorite, tracked: tracked));
    if (!state.hasError) ref.invalidate(healthCatalogProvider);
  }
}

final AsyncNotifierProvider<HealthWatchController, void> healthWatchControllerProvider = AsyncNotifierProvider<HealthWatchController, void>(HealthWatchController.new);

final Provider<SymptomsRepository> symptomsRepositoryProvider = Provider<SymptomsRepository>((Ref ref) => const SupabaseSymptomsRepository());
final FutureProvider<List<SymptomEntry>> symptomsProvider = FutureProvider<List<SymptomEntry>>((Ref ref) => ref.watch(symptomsRepositoryProvider).list());
final symptomProvider = FutureProvider.family<SymptomEntry?, String>((Ref ref, String id) => ref.watch(symptomsRepositoryProvider).get(id));

final Provider<AlertsRepository> alertsRepositoryProvider = Provider<AlertsRepository>((Ref ref) => const SupabaseAlertsRepository());
final FutureProvider<List<HealthAlert>> alertsProvider = FutureProvider<List<HealthAlert>>((Ref ref) => ref.watch(alertsRepositoryProvider).list());
final FutureProvider<int> unreadAlertsProvider = FutureProvider<int>((Ref ref) => ref.watch(alertsRepositoryProvider).unreadCount());

void invalidateHealthAlerts(Ref ref) {
  ref.invalidate(alertsProvider);
  ref.invalidate(unreadAlertsProvider);
}