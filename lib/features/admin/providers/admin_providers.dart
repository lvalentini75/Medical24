import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:medical24/features/admin/data/admin_models.dart';
import 'package:medical24/features/admin/data/admin_repository.dart';

final Provider<AdminRepository> adminRepositoryProvider = Provider<AdminRepository>((Ref ref) => AdminRepository());
final FutureProvider<bool> isAdminProvider = FutureProvider<bool>((Ref ref) => ref.watch(adminRepositoryProvider).isAdmin());
final FutureProvider<AdminOverviewData> adminOverviewProvider = FutureProvider<AdminOverviewData>((Ref ref) => ref.watch(adminRepositoryProvider).overview());
final FutureProvider<List<AdminAiTask>> adminTasksProvider = FutureProvider<List<AdminAiTask>>((Ref ref) => ref.watch(adminRepositoryProvider).tasks());
final FutureProvider<List<AdminAiModel>> adminModelsProvider = FutureProvider<List<AdminAiModel>>((Ref ref) => ref.watch(adminRepositoryProvider).models());
final FutureProvider<List<AdminSetting>> adminSettingsProvider = FutureProvider<List<AdminSetting>>((Ref ref) => ref.watch(adminRepositoryProvider).settings());
final adminSettingHistoryProvider = FutureProvider.family<List<AdminSetting>, String>((Ref ref, String key) => ref.watch(adminRepositoryProvider).settingHistory(key));
final adminPromptsProvider = FutureProvider.family<List<AdminPrompt>, String>((Ref ref, String task) => ref.watch(adminRepositoryProvider).prompts(task));

class AdminRange {
  const AdminRange(this.from, this.to, {this.task, this.status, this.type, this.action, this.actor, this.page = 0});
  final DateTime from, to;
  final String? task, status, type, action, actor;
  final int page;
  @override bool operator ==(Object other) => other is AdminRange && from == other.from && to == other.to && task == other.task && status == other.status && type == other.type && action == other.action && actor == other.actor && page == other.page;
  @override int get hashCode => Object.hash(from, to, task, status, type, action, actor, page);
}

final adminUsageProvider = FutureProvider.family<List<AdminUsageRow>, AdminRange>((Ref ref, AdminRange range) => ref.watch(adminRepositoryProvider).usage(range.from, range.to, range.task));
final adminCallsProvider = FutureProvider.family<List<AdminAiCall>, AdminRange>((Ref ref, AdminRange range) => ref.watch(adminRepositoryProvider).aiCalls(range.from, range.to, task: range.task, status: range.status, offset: range.page * 50));
final adminEventsProvider = FutureProvider.family<List<AdminEvent>, AdminRange>((Ref ref, AdminRange range) => ref.watch(adminRepositoryProvider).events(range.from, range.to, type: range.type, offset: range.page * 100));
final adminAuditProvider = FutureProvider.family<List<AdminAuditEntry>, AdminRange>((Ref ref, AdminRange range) => ref.watch(adminRepositoryProvider).audit(range.from, range.to, action: range.action, actor: range.actor, offset: range.page * 100));
final adminRulesProvider = FutureProvider<List<AdminRule>>((Ref ref) => ref.watch(adminRepositoryProvider).rules());