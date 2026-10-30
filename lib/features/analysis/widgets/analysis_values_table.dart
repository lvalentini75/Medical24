import 'package:flutter/material.dart';
import 'package:medical24/core/models/biomarker.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Compact extracted-value table used by report detail and analysis screens.
class AnalysisValuesTable extends StatelessWidget {
  const AnalysisValuesTable({super.key, required this.observations, required this.catalog});
  final List<Observation> observations;
  final Map<String, Biomarker> catalog;

  @override
  Widget build(BuildContext context) {
    if (observations.isEmpty) return Padding(padding: const EdgeInsets.all(24), child: Text(context.l10n.t('analysisEmptyBody')));
    return M24Card(padding: EdgeInsets.zero, child: Column(children: <Widget>[
      Container(color: context.m24.colors.surfaceAlt, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: <Widget>[Expanded(flex: 4, child: Text(context.l10n.t('homeTableParameter'), style: context.m24.text.label)), Expanded(flex: 3, child: Text(context.l10n.t('analysisValueColumn'), style: context.m24.text.label)), Expanded(flex: 3, child: Text(context.l10n.t('homeTableVerification'), style: context.m24.text.label))])),
      for (int i = 0; i < observations.length; i++) AnalysisValueRow(observation: observations[i], biomarker: catalog[observations[i].code], showDivider: i < observations.length - 1),
    ]));
  }
}

class AnalysisValueRow extends StatelessWidget {
  const AnalysisValueRow({super.key, required this.observation, this.biomarker, this.showDivider = false});
  final Observation observation;
  final Biomarker? biomarker;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final String name = biomarker?.name(Localizations.localeOf(context).languageCode) ?? (observation.displayName.isEmpty ? observation.code : observation.displayName);
    final M24StatusPillVariant variant = observation.needsReview ? M24StatusPillVariant.warning : switch (observation.flag) { ObservationFlag.criticalLow || ObservationFlag.criticalHigh => M24StatusPillVariant.danger, ObservationFlag.below || ObservationFlag.above => M24StatusPillVariant.warning, ObservationFlag.within => M24StatusPillVariant.success, _ => M24StatusPillVariant.neutral };
    final String label = observation.needsReview ? context.l10n.t('archiveStatus_needs_review') : context.l10n.t('analysisFlag_${observation.flag.value}');
    return Container(decoration: BoxDecoration(color: observation.needsReview ? context.m24.colors.warningTint : context.m24.colors.surface, border: showDivider ? Border(bottom: BorderSide(color: context.m24.colors.divider)) : null), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: <Widget>[
      Expanded(flex: 4, child: Text(name, style: context.m24.text.title, overflow: TextOverflow.ellipsis)),
      Expanded(flex: 3, child: Text(observation.displayValue(), style: context.m24.text.bodySmall)),
      Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: M24StatusPill(label: label, variant: variant))),
    ]));
  }
}

/// Retained for detailed range layouts that consume this public component.
class ValueCell extends StatelessWidget {
  const ValueCell({super.key, required this.label, required this.value, this.detail, this.flag});
  final String label, value;
  final String? detail;
  final ObservationFlag? flag;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(label, style: context.m24.text.label), Text(value, style: context.m24.text.title), if (detail != null) Text(detail!, style: context.m24.text.caption), if (flag != null) M24StatusPill(label: context.l10n.t('analysisFlag_${flag!.value}'), variant: flag == ObservationFlag.within ? M24StatusPillVariant.success : M24StatusPillVariant.warning)]);
}