import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/data/health_repository.dart';
import 'package:medical24/features/health/data/alert_models.dart';
import 'package:medical24/features/health/data/alerts_repository.dart';
import 'package:medical24/features/health/data/symptom_models.dart';
import 'package:medical24/features/health/data/symptoms_repository.dart';
import 'package:medical24/features/family/providers/family_providers.dart';
import 'package:medical24/core/providers/app_providers.dart';

final Provider<HealthRepository> healthRepositoryProvider = Provider<HealthRepository>((Ref ref) => SupabaseHealthRepository(ref.watch(currentSubjectProvider).value?.id));

final FutureProvider<List<BiomarkerSummary>> healthCatalogProvider = FutureProvider<List<BiomarkerSummary>>((Ref ref) {
  return ref.watch(currentSubjectProvider).value == null ? Future<List<BiomarkerSummary>>.value(const <BiomarkerSummary>[]) : ref.watch(healthRepositoryProvider).catalog();
});

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
  if (ref.watch(currentSubjectProvider).value == null) return Future<BiomarkerHistoryData>.error(StateError('subject_unavailable'));
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

final Provider<SymptomsRepository> symptomsRepositoryProvider = Provider<SymptomsRepository>((Ref ref) => SupabaseSymptomsRepository(ref.watch(currentSubjectProvider).value?.id));
final FutureProvider<List<SymptomEntry>> symptomsProvider = FutureProvider<List<SymptomEntry>>((Ref ref) => ref.watch(symptomsRepositoryProvider).list());
final symptomProvider = FutureProvider.family<SymptomEntry?, String>((Ref ref, String id) => ref.watch(symptomsRepositoryProvider).get(id));

final Provider<AlertsRepository> alertsRepositoryProvider = Provider<AlertsRepository>((Ref ref) => SupabaseAlertsRepository(ref.watch(currentSubjectProvider).value?.id));
final FutureProvider<List<HealthAlert>> alertsProvider = FutureProvider<List<HealthAlert>>((Ref ref) => ref.watch(alertsRepositoryProvider).list());
final FutureProvider<int> unreadAlertsProvider = FutureProvider<int>((Ref ref) => ref.watch(alertsRepositoryProvider).unreadCount());
final alertsForSubjectProvider = Provider.family<AlertsRepository, String>((Ref ref, String subjectId) => SupabaseAlertsRepository(subjectId));

final FutureProvider<List<SubjectHealthAlert>> alertCenterProvider = FutureProvider<List<SubjectHealthAlert>>((Ref ref) async {
  final String? userId = ref.watch(sessionProvider)?.user.id;
  if (userId == null) return const <SubjectHealthAlert>[];
  final subjects = await ref.watch(mySubjectsProvider.future);
  final List<List<SubjectHealthAlert>> groups = await Future.wait(subjects.map((subject) async {
    final bool isSelf = subject.id == userId;
    final List<HealthAlert> alerts = await ref.watch(alertsForSubjectProvider(subject.id)).list();
    return alerts.where((alert) => isSelf || alert.type == HealthAlertType.critical || alert.type == HealthAlertType.warning).map((alert) => SubjectHealthAlert(alert: alert, subjectId: subject.id, subjectName: subject.fullName, isSelf: isSelf)).toList(growable: false);
  }));
  return groups.expand((group) => group).toList(growable: false)..sort((a, b) => b.alert.createdAt.compareTo(a.alert.createdAt));
});

void invalidateHealthAlerts(Ref ref) {
  ref.invalidate(alertsProvider);
  ref.invalidate(unreadAlertsProvider);
  ref.invalidate(alertCenterProvider);
}