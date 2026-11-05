import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical24/features/home/data/home_models.dart';
import 'package:medical24/features/home/data/home_repository.dart';
import 'package:medical24/features/family/providers/family_providers.dart';
import 'package:medical24/core/providers/app_providers.dart';

final Provider<HomeRepository> homeRepositoryProvider = Provider<HomeRepository>((Ref ref) => const SupabaseHomeRepository());
final FutureProvider<HomeSnapshot> homeSnapshotProvider = FutureProvider<HomeSnapshot>((Ref ref) {
  final String? subjectId = ref.watch(currentSubjectProvider).value?.id;
  if (subjectId == null) return Future<HomeSnapshot>.error(StateError('subject_unavailable'));
  return ref.watch(homeRepositoryProvider).snapshot(subjectId);
});

final FutureProvider<List<FamilyHomeSnapshot>> familyHomeSnapshotsProvider = FutureProvider<List<FamilyHomeSnapshot>>((Ref ref) async {
  final String? userId = ref.watch(sessionProvider)?.user.id;
  if (userId == null) return const <FamilyHomeSnapshot>[];
  final subjects = (await ref.watch(mySubjectsProvider.future)).where((subject) => subject.id != userId).toList(growable: false);
  return Future.wait(subjects.map((subject) async {
    await ref.read(currentSubjectProvider.notifier).logViewOnce(subject.id);
    return FamilyHomeSnapshot(subject: subject, snapshot: await ref.watch(homeRepositoryProvider).snapshot(subject.id));
  }));
});