import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:medical24/features/admin/data/admin_models.dart';
import 'package:medical24/features/admin/data/admin_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<AdminRepository> adminRepositoryProvider = Provider<AdminRepository>((Ref ref) => AdminRepository());
final isAdminProvider = FutureProvider.autoDispose<bool>((Ref ref) => ref.watch(adminRepositoryProvider).isAdmin());
final adminOverviewProvider = FutureProvider.autoDispose<AdminOverviewData>((Ref ref) => ref.watch(adminRepositoryProvider).overview());
final adminTasksProvider = FutureProvider.autoDispose<List<AdminAiTask>>((Ref ref) => ref.watch(adminRepositoryProvider).tasks());
final adminModelsProvider = FutureProvider.autoDispose<List<AdminAiModel>>((Ref ref) => ref.watch(adminRepositoryProvider).models());
final adminSettingsProvider = FutureProvider.autoDispose<List<AdminSetting>>((Ref ref) => ref.watch(adminRepositoryProvider).settings());
final adminSettingHistoryProvider = FutureProvider.autoDispose.family<List<AdminSetting>, String>((Ref ref, String key) => ref.watch(adminRepositoryProvider).settingHistory(key));
final adminPromptsProvider = FutureProvider.autoDispose.family<List<AdminPrompt>, String>((Ref ref, String task) => ref.watch(adminRepositoryProvider).prompts(task));

class AdminRangeFilter {
  const AdminRangeFilter(this.from, this.to, {this.task, this.kind, this.action, this.actor, this.status, this.page = 0});
  final String from, to;
  DateTime get fromDate => DateTime.parse(from);
  DateTime get toDate => DateTime.parse(to);
  final String? task, kind, action, actor, status;
  final int page;
  @override bool operator ==(Object other) => other is AdminRangeFilter && from == other.from && to == other.to && task == other.task && status == other.status && kind == other.kind && action == other.action && actor == other.actor && page == other.page;
  @override int get hashCode => Object.hash(from, to, task, status, kind, action, actor, page);
}
typedef AdminRange = AdminRangeFilter;

final adminUsageProvider = FutureProvider.autoDispose.family<List<AdminUsageRow>, AdminRangeFilter>((Ref ref, AdminRangeFilter range) => ref.watch(adminRepositoryProvider).usage(range.fromDate, range.toDate, range.task));
final adminCallsProvider = FutureProvider.autoDispose.family<List<AdminAiCall>, AdminRangeFilter>((Ref ref, AdminRangeFilter range) => ref.watch(adminRepositoryProvider).aiCalls(range.fromDate, range.toDate, task: range.task, status: range.status, offset: range.page * 50));
final adminEventsProvider = FutureProvider.autoDispose.family<List<AdminEvent>, AdminRangeFilter>((Ref ref, AdminRangeFilter range) => ref.watch(adminRepositoryProvider).events(range.fromDate, range.toDate, type: range.kind, offset: range.page * 100));
final adminAuditProvider = FutureProvider.autoDispose.family<List<AdminAuditEntry>, AdminRangeFilter>((Ref ref, AdminRangeFilter range) => ref.watch(adminRepositoryProvider).audit(range.fromDate, range.toDate, action: range.action, actor: range.actor, offset: range.page * 100));
final adminRulesProvider = FutureProvider.autoDispose<List<AdminRule>>((Ref ref) => ref.watch(adminRepositoryProvider).rules());
final adminTreatmentsProvider = FutureProvider.autoDispose.family<List<AdminTreatment>, AdminTreatmentQuery>((Ref ref, AdminTreatmentQuery query) => ref.watch(adminRepositoryProvider).treatments(query));
final adminTreatmentProvider = FutureProvider.autoDispose.family<AdminTreatment?, String>((Ref ref, String id) => ref.watch(adminRepositoryProvider).treatment(id));
final adminDoctorsProvider = FutureProvider.autoDispose<List<AdminDoctor>>((Ref ref) => ref.watch(adminRepositoryProvider).doctors());
final adminFacilitiesProvider = FutureProvider.autoDispose<List<AdminFacility>>((Ref ref) => ref.watch(adminRepositoryProvider).facilities());
final adminTreatmentTagsProvider = FutureProvider.autoDispose<List<AdminTreatmentTag>>((Ref ref) => ref.watch(adminRepositoryProvider).treatmentTags());
final adminReviewsProvider = FutureProvider.autoDispose.family<List<AdminReview>, AdminReviewQuery>((Ref ref, AdminReviewQuery query) => ref.watch(adminRepositoryProvider).reviews(query));
final adminPendingReviewsProvider = FutureProvider.autoDispose<int>((Ref ref) => ref.watch(adminRepositoryProvider).pendingReviewCount());

String adminErrorMessage(Object error) => error is PostgrestException ? '${error.code}: ${error.message}' : '$error';