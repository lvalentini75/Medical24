import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical24/core/providers/app_providers.dart';
import 'package:medical24/features/family/data/family_repository.dart';
import 'package:medical24/features/home/providers/home_providers.dart';
import 'package:medical24/features/archive/providers/archive_providers.dart';
import 'package:medical24/features/analysis/providers/analysis_providers.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/features/health/body/providers/body_providers.dart';
import 'package:medical24/features/health/prevention/providers/prevention_providers.dart';
import 'package:medical24/features/doctor/providers/doctor_providers.dart';

final Provider<FamilyRepository> familyRepositoryProvider = Provider<FamilyRepository>((Ref ref) => const SupabaseFamilyRepository());
final FutureProvider<List<FamilySubject>> mySubjectsProvider = FutureProvider<List<FamilySubject>>((Ref ref) => ref.watch(familyRepositoryProvider).mySubjects());
final FutureProvider<List<FamilyInvitation>> pendingInvitationsProvider = FutureProvider<List<FamilyInvitation>>((Ref ref) => ref.watch(familyRepositoryProvider).pendingInvitations());
final FutureProvider<List<FamilyDelegate>> familyDelegatesProvider = FutureProvider<List<FamilyDelegate>>((Ref ref) => ref.watch(familyRepositoryProvider).delegates());
final FutureProvider<int> familyManagedLimitProvider = FutureProvider<int>((Ref ref) => ref.watch(familyRepositoryProvider).managedLimit());

class CurrentSubjectNotifier extends AsyncNotifier<FamilySubject?> {
  final Set<String> _viewedSubjects = <String>{};

  @override
  Future<FamilySubject?> build() async {
    final String? uid = ref.watch(sessionProvider)?.user.id;
    if (uid == null) return null;
    final List<FamilySubject> subjects = await ref.watch(mySubjectsProvider.future);
    if (subjects.isEmpty) return null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('current_subject_$uid');
    final FamilySubject selected = subjects.where((FamilySubject item) => item.id == saved).firstOrNull ?? subjects.where((FamilySubject item) => item.id == uid).firstOrNull ?? subjects.first;
    await logViewOnce(selected.id);
    return selected;
  }

  Future<void> logViewOnce(String subjectId) async {
    final String? uid = ref.read(sessionProvider)?.user.id;
    if (uid == null || subjectId == uid || !_viewedSubjects.add(subjectId)) return;
    try {
      await ref.read(familyRepositoryProvider).logSubjectView(subjectId);
    } catch (_) {
      _viewedSubjects.remove(subjectId);
      rethrow;
    }
  }

  Future<void> select(FamilySubject subject) async {
    final String? uid = ref.read(sessionProvider)?.user.id;
    if (uid == null) return;
    final List<FamilySubject> subjects = await ref.read(mySubjectsProvider.future);
    if (!subjects.any((FamilySubject item) => item.id == subject.id)) return;
    await logViewOnce(subject.id);
    await (await SharedPreferences.getInstance()).setString('current_subject_$uid', subject.id);
    state = AsyncValue<FamilySubject?>.data(subject);
    ref.invalidate(homeSnapshotProvider);
    ref.invalidate(familyHomeSnapshotsProvider);
    ref.invalidate(archiveListProvider);
    ref.invalidate(archiveYearsProvider);
    ref.invalidate(archiveUsageProvider);
    ref.invalidate(subjectExtractionsProvider);
    ref.invalidate(pendingReviewProvider);
    ref.invalidate(latestObservationsProvider);
    ref.invalidate(observationHistoryProvider);
    ref.invalidate(healthCatalogProvider);
    ref.invalidate(healthHistoryProvider);
    ref.invalidate(symptomsProvider);
    ref.invalidate(alertsProvider);
    ref.invalidate(unreadAlertsProvider);
    ref.invalidate(organOverviewProvider);
    ref.invalidate(organBiomarkersProvider);
    ref.invalidate(organHistoryProvider);
    ref.invalidate(organComparisonProvider);
    ref.invalidate(organEpisodesProvider);
    ref.invalidate(preventionSnapshotProvider);
    ref.invalidate(doctorLinksProvider);
    ref.invalidate(doctorDossierProvider);
    ref.invalidate(doctorQuestionsProvider);
    ref.invalidate(doctorEmergencyCardProvider);
  }

  Future<void> selectSelf() async {
    final String? uid = ref.read(sessionProvider)?.user.id;
    if (uid == null) return;
    final List<FamilySubject> subjects = await ref.read(mySubjectsProvider.future);
    final FamilySubject? self = subjects.where((FamilySubject item) => item.id == uid).firstOrNull;
    if (self != null) await select(self);
  }
}

final AsyncNotifierProvider<CurrentSubjectNotifier, FamilySubject?> currentSubjectProvider = AsyncNotifierProvider<CurrentSubjectNotifier, FamilySubject?>(CurrentSubjectNotifier.new);

extension FirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }