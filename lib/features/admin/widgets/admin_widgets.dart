import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/data_display.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';
import 'package:medical24/features/admin/data/admin_models.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

String adminMoney(int? microUsd) => '\$${((microUsd ?? 0) / 1000000).toStringAsFixed(4)}';
String adminJson(dynamic value) => const JsonEncoder.withIndent('  ').convert(value);
String adminDate(BuildContext context, DateTime? date) => date == null ? '-' : DateFormat.yMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(date.toLocal());

class AdminOverviewContent extends StatelessWidget {
  const AdminOverviewContent({super.key, required this.data});
  final AdminOverviewData data;

  @override
  Widget build(BuildContext context) {
    final Map<String, int> extraction = data.extractions;
    final List<(IconData, String, String)> stats = <(IconData, String, String)>[
      (M24Icons.users, context.l10n.adminUsersTotal, '${data.usersTotal}'),
      (M24Icons.users, context.l10n.adminUsersActive7d, '${data.usersActive7d}'),
      (M24Icons.users, context.l10n.adminUsersActive30d, '${data.usersActive30d}'),
      (M24Icons.document, context.l10n.adminDocuments, '${data.documents}'),
      (M24Icons.confirm, context.l10n.adminExtractionsOk, '${extraction['ok'] ?? 0}'),
      (M24Icons.error, context.l10n.adminExtractionsFailed, '${extraction['failed'] ?? 0}'),
      (M24Icons.review, context.l10n.adminExtractionsReview, '${extraction['review'] ?? 0}'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 4, childAspectRatio: 2.8, mainAxisSpacing: 12, crossAxisSpacing: 12, children: stats.map(((IconData, String, String) stat) => M24StatTile(icon: stat.$1, label: stat.$2, value: stat.$3)).toList()),
      const SizedBox(height: 20),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Expanded(child: AdminMapCard(title: context.l10n.adminCostToday, values: data.costToday, money: true)), const SizedBox(width: 16),
        Expanded(child: AdminMapCard(title: context.l10n.adminCostMonth, values: data.costMonth, money: true)), const SizedBox(width: 16),
        Expanded(child: AdminMapCard(title: context.l10n.adminErrors24h, values: data.errors)),
      ]),
      const SizedBox(height: 20),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Expanded(child: M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(context.l10n.adminTaskStatus, style: context.m24.text.h3), const SizedBox(height: 12), for (final AdminTaskState task in data.tasks) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: <Widget>[Expanded(child: Text(task.id)), M24StatusPill(label: task.paused ? context.l10n.adminPausedUntil(adminDate(context, task.pausedUntil)) : task.enabled ? context.l10n.adminActive : context.l10n.adminDisabled, variant: task.paused ? M24StatusPillVariant.warning : task.enabled ? M24StatusPillVariant.success : M24StatusPillVariant.neutral)]))]))),
        const SizedBox(width: 16),
        Expanded(child: M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(context.l10n.adminLastHealth, style: context.m24.text.h3), const SizedBox(height: 12), Text(adminDate(context, data.lastHealth?.at), style: context.m24.text.title), const SizedBox(height: 6), Text(data.lastHealth?.status ?? '-', style: context.m24.text.body), const SizedBox(height: 10), SelectableText(adminJson(data.lastHealth?.details ?? <String, dynamic>{}), style: context.m24.text.caption)]))),
      ]),
    ]);
  }
}

class AdminMapCard extends StatelessWidget {
  const AdminMapCard({super.key, required this.title, required this.values, this.money = false});
  final String title;
  final Map<String, int> values;
  final bool money;
  @override
  Widget build(BuildContext context) => M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: context.m24.text.h3), const SizedBox(height: 12), if (values.isEmpty) Text('-', style: context.m24.text.bodySmall), for (final MapEntry<String, int> item in values.entries) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: <Widget>[Expanded(child: Text(item.key, overflow: TextOverflow.ellipsis)), Text(money ? adminMoney(item.value) : '${item.value}', style: context.m24.text.title)]))]));
}

class AdminBudgetBar extends StatelessWidget {
  const AdminBudgetBar({super.key, required this.spent, this.budget});
  final int spent;
  final int? budget;
  @override
  Widget build(BuildContext context) {
    final double progress = budget == null || budget == 0 ? 0 : spent / budget!;
    final Color color = progress > 1 ? context.m24.colors.danger : progress >= .8 ? context.m24.colors.warning : context.m24.colors.success;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text('${adminMoney(spent)} / ${budget == null ? '-' : adminMoney(budget)}'), const SizedBox(height: 5), ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress.clamp(0, 1), minHeight: 7, color: color, backgroundColor: context.m24.colors.surfaceMuted))]);
  }
}

class AdminTaskForm extends StatefulWidget {
  const AdminTaskForm({super.key, required this.task, required this.models, required this.onSave, this.onResume, this.onPause});
  final AdminAiTask task;
  final List<AdminAiModel> models;
  final Future<void> Function(Map<String, dynamic> patch) onSave;
  final Future<void> Function()? onResume, onPause;
  @override
  State<AdminTaskForm> createState() => _AdminTaskFormState();
}

class _AdminTaskFormState extends State<AdminTaskForm> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late String model, fallback, budgetAction;
  late bool enabledFallback, enabled, secondApproval;
  late TextEditingController tokens, budget, userLimit, options;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    model = widget.task.model; fallback = widget.task.fallbackModel ?? model; budgetAction = widget.task.budgetAction; enabledFallback = widget.task.enabledFallback; enabled = widget.task.enabled; secondApproval = widget.task.requiresSecondApproval;
    tokens = TextEditingController(text: '${widget.task.maxOutputTokens}'); budget = TextEditingController(text: widget.task.dailyBudgetMicroUsd == null ? '' : (widget.task.dailyBudgetMicroUsd! / 1000000).toString()); userLimit = TextEditingController(text: widget.task.perUserDailyLimit?.toString() ?? ''); options = TextEditingController(text: adminJson(widget.task.requestOptions));
  }
  @override
  void dispose() { tokens.dispose(); budget.dispose(); userLimit.dispose(); options.dispose(); super.dispose(); }
  dynamic _json() { try { return jsonDecode(options.text); } catch (_) { return null; } }
  @override
  Widget build(BuildContext context) => Form(key: formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    Text(widget.task.id, style: context.m24.text.h2), Text(widget.task.description, style: context.m24.text.bodySmall), const SizedBox(height: 20),
    DropdownButtonFormField<String>(value: model, decoration: InputDecoration(labelText: context.l10n.adminModel), items: widget.models.where((m) => m.status == 'active').map((m) => DropdownMenuItem<String>(value: m.id, child: Text(m.displayName))).toList(), onChanged: (v) => setState(() => model = v ?? model)),
    const SizedBox(height: 12), DropdownButtonFormField<String>(value: fallback, decoration: InputDecoration(labelText: context.l10n.adminFallback), items: widget.models.where((m) => m.status == 'active').map((m) => DropdownMenuItem<String>(value: m.id, child: Text(m.displayName))).toList(), onChanged: (v) => setState(() => fallback = v ?? fallback)),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.l10n.adminFallbackEnabled), value: enabledFallback, onChanged: (v) => setState(() => enabledFallback = v)),
    TextFormField(key: const Key('adminTaskMaxTokens'), controller: tokens, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.l10n.adminMaxOutputTokens), validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0 ? context.l10n.adminPositiveNumberError : null),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.l10n.adminEnabled), value: enabled, onChanged: (v) => setState(() => enabled = v)),
    TextFormField(controller: budget, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: context.l10n.adminDailyBudgetUsd)),
    const SizedBox(height: 12), DropdownButtonFormField<String>(value: budgetAction, decoration: InputDecoration(labelText: context.l10n.adminBudgetAction), items: <DropdownMenuItem<String>>[DropdownMenuItem(value: 'alert', child: Text(context.l10n.adminBudgetAlert)), DropdownMenuItem(value: 'pause', child: Text(context.l10n.adminBudgetPause))], onChanged: (v) => setState(() => budgetAction = v ?? budgetAction)),
    const SizedBox(height: 12), TextFormField(controller: userLimit, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.l10n.adminUserDailyLimit)),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.l10n.adminSecondApproval), value: secondApproval, onChanged: (v) => setState(() => secondApproval = v)),
    DropdownButtonFormField<String>(decoration: InputDecoration(labelText: context.l10n.adminRequestPreset), items: <DropdownMenuItem<String>>[for (final String effort in <String>['low','medium','high']) DropdownMenuItem(value: effort, child: Text(context.l10n.adminEffort(effort))), DropdownMenuItem(value: 'adaptive', child: Text(context.l10n.adminAdaptiveThinking))], onChanged: (value) { final dynamic preset = value == 'adaptive' ? <String, dynamic>{} : <String, dynamic>{'thinking': <String, dynamic>{'type': 'between_tools'}, 'output_config': <String, dynamic>{'effort': value}}; options.text = adminJson(preset); }),
    const SizedBox(height: 12), TextFormField(key: const Key('adminTaskJson'), controller: options, minLines: 5, maxLines: 10, decoration: InputDecoration(labelText: context.l10n.adminRequestOptions), validator: (_) => _json() is! Map ? context.l10n.adminJsonObjectError : null),
    const SizedBox(height: 20), Row(children: <Widget>[if (widget.task.pausedUntil?.isAfter(DateTime.now()) ?? false) Expanded(child: M24Button(label: context.l10n.adminResume, variant: M24ButtonVariant.outlinePrimary, onPressed: widget.onResume == null ? null : () => widget.onResume!())), if (widget.task.pausedUntil?.isAfter(DateTime.now()) ?? false) const SizedBox(width: 8), Expanded(child: M24Button(label: context.l10n.adminPauseTomorrow, variant: M24ButtonVariant.warning, onPressed: widget.onPause == null ? null : () => widget.onPause!()))]),
    const SizedBox(height: 12), M24Button(label: context.l10n.commonSave, loading: saving, onPressed: _save),
  ]));

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final Map<String, dynamic> current = <String, dynamic>{'model_id': model, 'fallback_model_id': fallback, 'enabled_fallback': enabledFallback, 'max_output_tokens': int.parse(tokens.text), 'enabled': enabled, 'daily_budget_micro_usd': budget.text.trim().isEmpty ? null : (double.parse(budget.text) * 1000000).round(), 'budget_action': budgetAction, 'per_user_daily_limit': userLimit.text.trim().isEmpty ? null : int.parse(userLimit.text), 'requires_second_approval': secondApproval, 'request_options': _json()};
    final Map<String, dynamic> original = <String, dynamic>{'model_id': widget.task.model, 'fallback_model_id': widget.task.fallbackModel, 'enabled_fallback': widget.task.enabledFallback, 'max_output_tokens': widget.task.maxOutputTokens, 'enabled': widget.task.enabled, 'daily_budget_micro_usd': widget.task.dailyBudgetMicroUsd, 'budget_action': widget.task.budgetAction, 'per_user_daily_limit': widget.task.perUserDailyLimit, 'requires_second_approval': widget.task.requiresSecondApproval, 'request_options': widget.task.requestOptions};
    current.removeWhere((key, value) => adminJson(value) == adminJson(original[key]));
    setState(() => saving = true); try { await widget.onSave(current); } finally { if (mounted) setState(() => saving = false); }
  }
}

class AdminSidePanel extends StatelessWidget {
  const AdminSidePanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.centerRight, child: Material(color: context.m24.colors.surface, elevation: 12, child: SizedBox(width: 520, height: double.infinity, child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: child))));
}

class AdminJsonSettingForm extends StatefulWidget {
  const AdminJsonSettingForm({super.key, required this.setting, required this.onSave});
  final AdminSetting setting;
  final Future<void> Function(dynamic value) onSave;
  @override
  State<AdminJsonSettingForm> createState() => _AdminJsonSettingFormState();
}

class _AdminJsonSettingFormState extends State<AdminJsonSettingForm> {
  final GlobalKey<FormState> key = GlobalKey<FormState>(); late final TextEditingController controller = TextEditingController(text: adminJson(widget.setting.value));
  dynamic parsed() { try { return jsonDecode(controller.text); } catch (_) { return null; } }
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Form(key: key, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(widget.setting.key, style: context.m24.text.h2), const SizedBox(height: 16), TextFormField(controller: controller, minLines: 8, maxLines: 18, decoration: InputDecoration(labelText: context.l10n.adminValueJson), validator: (_) { try { jsonDecode(controller.text); return null; } catch (_) { return context.l10n.adminJsonInvalid; } }), const SizedBox(height: 16), M24Button(label: context.l10n.commonSave, onPressed: () async { if (key.currentState!.validate()) await widget.onSave(parsed()); })]));
}

class AdminMaintenanceControl extends StatelessWidget {
  const AdminMaintenanceControl({super.key, required this.enabled, required this.onChanged});
  final bool enabled;
  final Future<void> Function(bool value) onChanged;
  @override Widget build(BuildContext context) => M24Card(child: SwitchListTile(key: const Key('adminMaintenanceSwitch'), contentPadding: EdgeInsets.zero, activeColor: context.m24.colors.danger, title: Text(context.l10n.adminMaintenance, style: context.m24.text.title.copyWith(color: context.m24.colors.danger)), subtitle: Text(context.l10n.adminMaintenanceBody), value: enabled, onChanged: (value) async { final bool? confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: Text(dialogContext.l10n.adminMaintenanceConfirmTitle), content: Text(dialogContext.l10n.adminMaintenanceConfirmBody), actions: <Widget>[TextButton(onPressed: () => dialogContext.pop(false), child: Text(dialogContext.l10n.commonCancel)), TextButton(key: const Key('adminMaintenanceConfirm'), onPressed: () => dialogContext.pop(true), child: Text(dialogContext.l10n.commonConfirm))])); if (confirmed == true) await onChanged(value); }));
}