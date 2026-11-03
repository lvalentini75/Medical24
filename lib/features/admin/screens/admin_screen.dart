import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/branding.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/data_display.dart';
import 'package:medical24/core/ui/widgets/navigation.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/admin/data/admin_models.dart';
import 'package:medical24/features/admin/providers/admin_providers.dart';
import 'package:medical24/features/admin/widgets/admin_widgets.dart';
import 'package:medical24/features/admin/screens/admin_governance_pages.dart';
import 'package:medical24/features/admin/screens/admin_content_pages.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AdminPage { overview, ai, settings, prompts, usage, events, audit, rules, treatments, treatmentEditor, providers, reviews }

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key, required this.page, this.treatmentId});
  final AdminPage page;
  final String? treatmentId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AdminAccessGate(isAdmin: ref.watch(isAdminProvider), child: AdminResponsiveShell(page: page, treatmentId: treatmentId));
}

class AdminAccessGate extends ConsumerWidget {
  const AdminAccessGate({super.key, required this.isAdmin, required this.child});
  final AsyncValue<bool> isAdmin;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => isAdmin.when(
    loading: () => const Scaffold(body: AppLoadingView()),
    error: (error, stack) => Scaffold(body: AppErrorView(message: adminErrorMessage(error), onRetry: () => ref.invalidate(isAdminProvider))),
    data: (allowed) => allowed ? child : Scaffold(body: Center(child: M24EmptyState(icon: M24Icons.government, title: context.l10n.adminForbiddenTitle, message: context.l10n.adminForbiddenBody, actionLabel: context.l10n.adminBackHome, onAction: () => context.go(AppRoutes.home)))),
  );
}

class AdminResponsiveShell extends StatelessWidget {
  const AdminResponsiveShell({super.key, required this.page, this.treatmentId});
  final AdminPage page;
  final String? treatmentId;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 1200) return Scaffold(body: SafeArea(child: Column(children: <Widget>[Padding(padding: const EdgeInsets.all(20), child: M24Breadcrumb(segments: <String>[context.l10n.adminGovernment, _title(context)])), Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: M24Card(child: M24EmptyState(icon: M24Icons.government, title: context.l10n.adminDesktopOnly, message: context.l10n.adminDesktopOnlyBody, actionLabel: context.l10n.adminBackHome, onAction: () => context.go(AppRoutes.home))))))])));
    return Scaffold(body: Row(children: <Widget>[AdminNavigation(page: page), Expanded(child: Column(children: <Widget>[SizedBox(height: 64, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Align(alignment: Alignment.centerLeft, child: M24Breadcrumb(segments: <String>[context.l10n.adminGovernment, _title(context)])))), Expanded(child: _page())]))]));
  }
  String _title(BuildContext context) => switch (page) { AdminPage.overview => context.l10n.adminOverview, AdminPage.ai => context.l10n.adminAiTasks, AdminPage.settings => context.l10n.adminSettings, AdminPage.prompts => context.l10n.adminPrompts, AdminPage.usage => context.l10n.adminUsage, AdminPage.events => context.l10n.adminEvents, AdminPage.audit => context.l10n.adminAudit, AdminPage.rules => context.l10n.adminRules, AdminPage.treatments || AdminPage.treatmentEditor => context.l10n.adminTreatments, AdminPage.providers => context.l10n.adminProviders, AdminPage.reviews => context.l10n.adminReviewModeration };
  Widget _page() => switch (page) { AdminPage.overview => const AdminOverviewPage(), AdminPage.ai => const AdminAiPage(), AdminPage.settings => const AdminSettingsPage(), AdminPage.prompts => const AdminPromptsPage(), AdminPage.usage => const AdminUsagePage(), AdminPage.events => const AdminEventsPage(), AdminPage.audit => const AdminAuditPage(), AdminPage.rules => const AdminRulesPage(), AdminPage.treatments => const AdminTreatmentsPage(), AdminPage.treatmentEditor => AdminTreatmentEditorPage(id: treatmentId), AdminPage.providers => const AdminProvidersPage(), AdminPage.reviews => const AdminReviewsPage() };
}

class AdminMenuItem {
  const AdminMenuItem({required this.label, required this.icon, required this.route, required this.page, this.group, this.badge});
  final String label;
  final IconData icon;
  final String route;
  final AdminPage page;
  final String? group;
  final int? badge;
}

class AdminNavigation extends ConsumerWidget {
  const AdminNavigation({super.key, required this.page});
  final AdminPage page;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int pendingReviews = ref.watch(adminPendingReviewsProvider).value ?? 0;
    final List<AdminMenuItem> items = <AdminMenuItem>[
      AdminMenuItem(label: context.l10n.adminOverview, icon: M24Icons.home, route: AppRoutes.adminOverview, page: AdminPage.overview),
      AdminMenuItem(label: context.l10n.adminAiTasks, icon: M24Icons.bot, route: AppRoutes.adminAi, page: AdminPage.ai),
      AdminMenuItem(label: context.l10n.adminSettings, icon: M24Icons.settings, route: AppRoutes.adminSettings, page: AdminPage.settings),
      AdminMenuItem(label: context.l10n.adminPrompts, icon: M24Icons.document, route: AppRoutes.adminPrompts, page: AdminPage.prompts),
      AdminMenuItem(label: context.l10n.adminUsage, icon: M24Icons.cost, route: AppRoutes.adminUsage, page: AdminPage.usage),
      AdminMenuItem(label: context.l10n.adminEvents, icon: M24Icons.alerts, route: AppRoutes.adminEvents, page: AdminPage.events),
      AdminMenuItem(label: context.l10n.adminAudit, icon: M24Icons.history, route: AppRoutes.adminAudit, page: AdminPage.audit),
      AdminMenuItem(label: context.l10n.adminRules, icon: M24Icons.government, route: AppRoutes.adminRules, page: AdminPage.rules),
      AdminMenuItem(label: context.l10n.adminTreatments, icon: M24Icons.treatments, route: AppRoutes.adminTreatments, page: AdminPage.treatments, group: context.l10n.adminContents),
      AdminMenuItem(label: context.l10n.adminProviders, icon: M24Icons.users, route: AppRoutes.adminProviders, page: AdminPage.providers, group: context.l10n.adminContents),
      AdminMenuItem(label: context.l10n.adminReviews, icon: M24Icons.review, route: AppRoutes.adminReviews, page: AdminPage.reviews, group: context.l10n.adminContents, badge: pendingReviews > 0 ? pendingReviews : null),
    ];
    final String location = GoRouterState.of(context).uri.path;
    return Container(width: 240, decoration: BoxDecoration(color: context.m24.colors.surface, border: Border(right: BorderSide(color: context.m24.colors.border))), child: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      const M24Logo(), const SizedBox(height: 24), Text(context.l10n.adminGovernment, style: context.m24.text.h3), const SizedBox(height: 16),
      for (final String? group in <String?>[null, context.l10n.adminContents]) ...<Widget>[
        if (group != null) ...<Widget>[const SizedBox(height: 10), Text(group, style: context.m24.text.caption), const SizedBox(height: 6)],
        for (final AdminMenuItem item in items.where((item) => item.group == group)) Padding(padding: const EdgeInsets.only(bottom: 5), child: ListTile(selected: location == item.route || location.startsWith('${item.route}/'), leading: Icon(item.icon, size: 20), title: Text(item.label), trailing: item.badge == null ? null : CircleAvatar(radius: 10, backgroundColor: context.m24.colors.warning, child: Text('${item.badge}', style: context.m24.text.caption.copyWith(color: Colors.white))), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), selectedTileColor: context.m24.colors.primarySoft, onTap: () => context.go(item.route))),
      ],
      const Spacer(), M24Button(label: context.l10n.adminBackToApp, icon: M24Icons.back, variant: M24ButtonVariant.outline, onPressed: () => context.go(AppRoutes.home)),
    ]))));
  }
}

class AdminOverviewPage extends ConsumerStatefulWidget { const AdminOverviewPage({super.key}); @override ConsumerState<AdminOverviewPage> createState() => _AdminOverviewPageState(); }
class _AdminOverviewPageState extends ConsumerState<AdminOverviewPage> {
  Timer? timer;
  @override void initState() { super.initState(); timer = Timer.periodic(const Duration(seconds: 60), (_) { if (mounted) ref.invalidate(adminOverviewProvider); }); }
  @override void dispose() { timer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) { final data = ref.watch(adminOverviewProvider); final pending = ref.watch(adminPendingReviewsProvider).value ?? 0; return AdminPageFrame(title: context.l10n.adminOverview, action: M24Button(label: context.l10n.adminRefresh, icon: M24Icons.refresh, variant: M24ButtonVariant.outlinePrimary, onPressed: () { ref.invalidate(adminOverviewProvider); ref.invalidate(adminPendingReviewsProvider); }), child: data.when(data: (value) => AdminOverviewContent(data: value, pendingReviews: pending, onPendingReviews: () => context.go(AppRoutes.adminReviews)), loading: () => const AppLoadingView(), error: (error, stack) => AppErrorView(message: adminErrorMessage(error), onRetry: () => ref.invalidate(adminOverviewProvider)))); }
}

class AdminAiPage extends ConsumerWidget {
  const AdminAiPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(adminTasksProvider); final models = ref.watch(adminModelsProvider);
    return AdminPageFrame(title: context.l10n.adminAiTasksModels, child: tasks.when(data: (taskData) => models.when(data: (modelData) => AdminAiTables(tasks: taskData, models: modelData), loading: () => const AppLoadingView(), error: (e, s) => AppErrorView(message: adminErrorMessage(e), onRetry: () => ref.invalidate(adminModelsProvider))), loading: () => const AppLoadingView(), error: (e, s) => AppErrorView(message: adminErrorMessage(e), onRetry: () => ref.invalidate(adminTasksProvider))));
  }
}

class AdminAiTables extends ConsumerWidget {
  const AdminAiTables({super.key, required this.tasks, required this.models});
  final List<AdminAiTask> tasks; final List<AdminAiModel> models;
  @override Widget build(BuildContext context, WidgetRef ref) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    Text(context.l10n.adminAiTasks, style: context.m24.text.h2), const SizedBox(height: 12), SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: 1200, child: M24Table(columns: <String>[context.l10n.adminTask, context.l10n.adminModel, context.l10n.adminFallback, context.l10n.adminPrompt, context.l10n.adminBudgetProgress, context.l10n.adminStatus, ''], fixedColumnWidth: 150, rows: tasks.map((task) => <Widget>[Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(task.id), Text(task.description, style: context.m24.text.caption)]), Text(task.model), Text(task.fallbackModel ?? '-'), Text(task.promptVersion ?? '-'), AdminBudgetBar(spent: task.spentToday, budget: task.dailyBudgetMicroUsd), Text(task.pausedUntil?.isAfter(DateTime.now()) ?? false ? context.l10n.adminPaused : task.enabled ? context.l10n.adminActive : context.l10n.adminDisabled), TextButton(onPressed: () => _editTask(context, ref, task), child: Text(context.l10n.adminEdit))]).toList()))),
    const SizedBox(height: 28), Row(children: <Widget>[Expanded(child: Text(context.l10n.adminModels, style: context.m24.text.h2)), M24Button(label: context.l10n.adminNewModel, icon: M24Icons.plus, onPressed: () => _editModel(context, ref, null))]), const SizedBox(height: 12),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: 1200, child: M24Table(columns: <String>[context.l10n.adminId, context.l10n.adminProvider, context.l10n.adminName, context.l10n.adminPriceInput, context.l10n.adminPriceOutput, context.l10n.adminPriceCache, context.l10n.adminContextWindow, context.l10n.adminStatus, ''], fixedColumnWidth: 125, rows: models.map((model) => <Widget>[Text(model.id), Text(model.provider), Text(model.displayName), Text(adminMoney(model.priceIn)), Text(adminMoney(model.priceOut)), Text(adminMoney(model.priceCached)), Text('${model.contextWindow ?? '-'}'), Text(model.status), TextButton(onPressed: () => _editModel(context, ref, model), child: Text(context.l10n.adminEdit))]).toList()))),
  ]);

  Future<void> _editTask(BuildContext context, WidgetRef ref, AdminAiTask task) async => showDialog<void>(context: context, barrierColor: context.m24.colors.overlay, builder: (dialogContext) => AdminSidePanel(child: AdminTaskForm(task: task, models: models, onSave: (patch) async { try { await ref.read(adminRepositoryProvider).setTask(task.id, patch); ref.invalidate(adminTasksProvider); if (dialogContext.mounted) dialogContext.pop(); } on PostgrestException catch (e) { if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(e.message))); } }, onResume: () async { await ref.read(adminRepositoryProvider).setTask(task.id, <String, dynamic>{'paused_until': null}); ref.invalidate(adminTasksProvider); }, onPause: () async { final DateTime tomorrow = DateTime.now().toUtc().add(const Duration(days: 1)); await ref.read(adminRepositoryProvider).setTask(task.id, <String, dynamic>{'paused_until': DateTime.utc(tomorrow.year, tomorrow.month, tomorrow.day).toIso8601String()}); ref.invalidate(adminTasksProvider); })));
  Future<void> _editModel(BuildContext context, WidgetRef ref, AdminAiModel? model) async => showDialog<void>(context: context, barrierColor: context.m24.colors.overlay, builder: (dialogContext) => AdminSidePanel(child: AdminModelForm(model: model, onSave: (id, patch) async { try { await ref.read(adminRepositoryProvider).setModel(id, patch); ref.invalidate(adminModelsProvider); if (dialogContext.mounted) dialogContext.pop(); } on PostgrestException catch (e) { final String message = e.message.contains('model_in_use') ? dialogContext.l10n.adminModelInUse : e.message; if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(message))); } })));
}

class AdminModelForm extends StatefulWidget {
  const AdminModelForm({super.key, this.model, required this.onSave}); final AdminAiModel? model; final Future<void> Function(String id, Map<String, dynamic> patch) onSave;
  @override State<AdminModelForm> createState() => _AdminModelFormState();
}
class _AdminModelFormState extends State<AdminModelForm> {
  final key = GlobalKey<FormState>(); late final id = TextEditingController(text: widget.model?.id); late final provider = TextEditingController(text: widget.model?.provider); late final name = TextEditingController(text: widget.model?.displayName); late final input = TextEditingController(text: widget.model?.priceIn == null ? '' : (widget.model!.priceIn! / 1000000).toString()); late final output = TextEditingController(text: widget.model?.priceOut == null ? '' : (widget.model!.priceOut! / 1000000).toString()); late final cache = TextEditingController(text: widget.model?.priceCached == null ? '' : (widget.model!.priceCached! / 1000000).toString()); late final window = TextEditingController(text: widget.model?.contextWindow?.toString()); late String status = widget.model?.status ?? 'active';
  @override Widget build(BuildContext context) => Form(key: key, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(widget.model == null ? context.l10n.adminNewModel : context.l10n.adminEditModel, style: context.m24.text.h2), const SizedBox(height: 16), for (final field in <(TextEditingController, String)>[(id, context.l10n.adminId),(provider, context.l10n.adminProvider),(name, context.l10n.adminName),(input, context.l10n.adminPriceInput),(output, context.l10n.adminPriceOutput),(cache, context.l10n.adminPriceCache),(window, context.l10n.adminContextWindow)]) Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: field.$1, enabled: widget.model == null || field.$1 != id, decoration: InputDecoration(labelText: field.$2), validator: (v) => (v ?? '').trim().isEmpty ? context.l10n.commonRequired : null)), DropdownButtonFormField<String>(value: status, decoration: InputDecoration(labelText: context.l10n.adminStatus), items: const <DropdownMenuItem<String>>[DropdownMenuItem(value: 'active', child: Text('active')), DropdownMenuItem(value: 'deprecated', child: Text('deprecated'))], onChanged: (v) => status = v ?? status), const SizedBox(height: 20), M24Button(label: context.l10n.commonSave, onPressed: () async { if (!key.currentState!.validate()) return; await widget.onSave(id.text.trim(), <String, dynamic>{'provider': provider.text.trim(), 'display_name': name.text.trim(), 'price_in_micro_usd_per_mtok': (double.parse(input.text) * 1000000).round(), 'price_out_micro_usd_per_mtok': (double.parse(output.text) * 1000000).round(), 'price_cached_in_micro_usd_per_mtok': (double.parse(cache.text) * 1000000).round(), 'context_window': int.parse(window.text), 'status': status}); })]));
}

class AdminSettingsPage extends ConsumerWidget {
  const AdminSettingsPage({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) { final settings = ref.watch(adminSettingsProvider); return AdminPageFrame(title: context.l10n.adminSettings, child: settings.when(data: (data) { final AdminSetting? maintenance = data.where((s) => s.key == 'platform.maintenance_mode').firstOrNull; return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[AdminMaintenanceControl(enabled: maintenance?.value == true, onChanged: (value) async { if (maintenance != null) { await ref.read(adminRepositoryProvider).setSetting(maintenance, value); ref.invalidate(adminSettingsProvider); } }), const SizedBox(height: 20), M24Table(columns: <String>[context.l10n.adminKey, context.l10n.adminValue, context.l10n.adminPublic, context.l10n.adminDescription, context.l10n.adminVersion, context.l10n.adminUpdatedAt, ''], fixedColumnWidth: 130, rows: data.map((setting) => <Widget>[Text(setting.key), Text(adminJson(setting.value), maxLines: 2, overflow: TextOverflow.ellipsis), Text(setting.isPublic ? context.l10n.commonYes : context.l10n.commonNo), Text(setting.description ?? '-'), Text('${setting.version}'), Text(adminDate(context, setting.updatedAt)), Row(children: <Widget>[TextButton(onPressed: () => _edit(context, ref, setting), child: Text(context.l10n.adminEdit)), TextButton(onPressed: () => _history(context, ref, setting), child: Text(context.l10n.adminHistory))])]).toList())]); }, loading: () => const AppLoadingView(), error: (e, s) => AppErrorView(message: adminErrorMessage(e), onRetry: () => ref.invalidate(adminSettingsProvider)))); }
  Future<void> _edit(BuildContext context, WidgetRef ref, AdminSetting setting) => showDialog<void>(context: context, builder: (dialogContext) => AdminSidePanel(child: AdminJsonSettingForm(setting: setting, onSave: (value) async { await ref.read(adminRepositoryProvider).setSetting(setting, value); ref.invalidate(adminSettingsProvider); if (dialogContext.mounted) dialogContext.pop(); })));
  Future<void> _history(BuildContext context, WidgetRef ref, AdminSetting setting) => showDialog<void>(context: context, builder: (dialogContext) => AdminSidePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(context.l10n.adminHistory, style: context.m24.text.h2), Text(setting.key), const SizedBox(height: 16), ref.watch(adminSettingHistoryProvider(setting.key)).when(data: (rows) => Column(children: rows.map((row) => ListTile(title: Text('v${row.version} · ${adminDate(context, row.updatedAt)}'), subtitle: Text(adminJson(row.value)))).toList()), loading: () => const AppLoadingView(), error: (e, s) => AppErrorView(message: adminErrorMessage(e), onRetry: () => ref.invalidate(adminSettingHistoryProvider(setting.key))))])));
}

class AdminPageFrame extends StatelessWidget {
  const AdminPageFrame({super.key, required this.title, required this.child, this.action}); final String title; final Widget child; final Widget? action;
  @override Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(32, 16, 32, 40), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Row(children: <Widget>[Expanded(child: Text(title, style: context.m24.text.h1)), if (action != null) action!]), const SizedBox(height: 24), child]));
}