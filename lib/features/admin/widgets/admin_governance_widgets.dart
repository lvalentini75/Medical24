import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';
import 'package:medical24/features/admin/data/admin_models.dart';
import 'package:medical24/features/admin/widgets/admin_widgets.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class AdminPromptActions extends StatelessWidget {
  const AdminPromptActions({super.key, required this.prompt, this.onApprove, this.onTest, this.onActivate, this.onCompare, this.onRestore});
  final AdminPrompt prompt;
  final VoidCallback? onApprove, onTest, onActivate, onCompare, onRestore;
  @override
  Widget build(BuildContext context) {
    if (prompt.status == 'active') return Wrap(spacing: 8, children: <Widget>[M24StatusPill(label: context.l10n.adminActive, variant: M24StatusPillVariant.success), M24Button(label: context.l10n.adminCompare, variant: M24ButtonVariant.outline, onPressed: onCompare)]);
    if (prompt.status == 'retired') return M24Button(label: context.l10n.adminRestore, variant: M24ButtonVariant.outlinePrimary, onPressed: onRestore);
    return Wrap(spacing: 8, runSpacing: 8, children: <Widget>[M24Button(label: context.l10n.adminApprove, variant: M24ButtonVariant.outlinePrimary, onPressed: onApprove), if (prompt.taskId == 'explain') M24Button(label: context.l10n.adminRunTest, variant: M24ButtonVariant.outline, onPressed: onTest), M24Button(label: context.l10n.adminActivate, onPressed: onActivate)]);
  }
}

class AdminDryRunResults extends StatelessWidget {
  const AdminDryRunResults({super.key, required this.cases});
  final List<AdminDryRunCase> cases;
  @override
  Widget build(BuildContext context) => Column(key: const Key('adminDryRunResults'), crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[for (final item in cases) Padding(padding: const EdgeInsets.only(bottom: 10), child: M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(item.name, style: context.m24.text.title), const SizedBox(height: 6), Text(item.text), const SizedBox(height: 8), Wrap(spacing: 8, children: <Widget>[M24StatusPill(label: context.l10n.adminFilterPassed, variant: item.filterPassed ? M24StatusPillVariant.success : M24StatusPillVariant.danger), M24StatusPill(label: context.l10n.adminClosingPresent, variant: item.closingPresent ? M24StatusPillVariant.success : M24StatusPillVariant.danger)])])))]);
}

class AdminUsageCharts extends StatelessWidget {
  const AdminUsageCharts({super.key, required this.rows});
  final List<AdminUsageRow> rows;
  @override
  Widget build(BuildContext context) {
    final List<DateTime> days = rows.map((e) => e.day).whereType<DateTime>().map((e) => DateTime(e.year, e.month, e.day)).toSet().toList()..sort();
    final List<String> tasks = rows.map((e) => e.task).toSet().toList();
    final List<Color> colors = <Color>[context.m24.colors.chart, context.m24.colors.indigo, context.m24.colors.warning];
    double cost(DateTime day, String task) => rows.where((e) => e.day != null && DateUtils.isSameDay(e.day, day) && e.task == task).fold(0, (sum, e) => sum + e.costMicroUsd / 1000000);
    int total(DateTime day, int Function(AdminUsageRow row) pick) => rows.where((e) => e.day != null && DateUtils.isSameDay(e.day, day)).fold(0, (sum, e) => sum + pick(e));
    return Column(key: const Key('adminUsageCharts'), children: <Widget>[
      Row(children: <Widget>[for (int i = 0; i < tasks.length; i++) Padding(padding: const EdgeInsets.only(right: 16), child: Row(children: <Widget>[Container(width: 10, height: 10, color: colors[i % colors.length]), const SizedBox(width: 6), Text(tasks[i])]))]), const SizedBox(height: 12),
      SizedBox(height: 240, child: BarChart(BarChartData(gridData: const FlGridData(show: false), borderData: FlBorderData(show: false), titlesData: const FlTitlesData(topTitles: AxisTitles(), rightTitles: AxisTitles()), barGroups: <BarChartGroupData>[for (int i = 0; i < days.length; i++) BarChartGroupData(x: i, barRods: <BarChartRodData>[for (int t = 0; t < tasks.length; t++) BarChartRodData(toY: cost(days[i], tasks[t]), width: math.max(4, 14 / math.max(1, tasks.length)), color: colors[t % colors.length], borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))])]))),
      const SizedBox(height: 24), SizedBox(height: 220, child: LineChart(LineChartData(gridData: const FlGridData(show: false), borderData: FlBorderData(show: false), titlesData: const FlTitlesData(topTitles: AxisTitles(), rightTitles: AxisTitles()), lineBarsData: <LineChartBarData>[
        LineChartBarData(color: context.m24.colors.success, spots: <FlSpot>[for (int i = 0; i < days.length; i++) FlSpot(i.toDouble(), total(days[i], (r) => r.ok).toDouble())]),
        LineChartBarData(color: context.m24.colors.danger, spots: <FlSpot>[for (int i = 0; i < days.length; i++) FlSpot(i.toDouble(), total(days[i], (r) => r.errors).toDouble())]),
        LineChartBarData(color: context.m24.colors.info, spots: <FlSpot>[for (int i = 0; i < days.length; i++) FlSpot(i.toDouble(), total(days[i], (r) => r.cached).toDouble())]),
      ]))),
    ]);
  }
}

class AdminPagination extends StatelessWidget {
  const AdminPagination({super.key, required this.page, required this.hasNext, required this.onPageChanged});
  final int page;
  final bool hasNext;
  final ValueChanged<int> onPageChanged;
  @override
  Widget build(BuildContext context) => Row(key: const Key('adminPagination'), mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[M24Button(label: context.l10n.adminPrevious, variant: M24ButtonVariant.outline, onPressed: page == 0 ? null : () => onPageChanged(page - 1)), Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('${page + 1}')), M24Button(label: context.l10n.adminNext, variant: M24ButtonVariant.outline, onPressed: hasNext ? () => onPageChanged(page + 1) : null)]);
}
