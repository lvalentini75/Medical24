import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/formatters.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/archive/widgets/add_document_sheet.dart';
import 'package:medical24/features/health/body/data/body_models.dart';
import 'package:medical24/features/health/body/providers/body_providers.dart';
import 'package:medical24/features/health/body/widgets/body_widgets.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/features/health/widgets/biomarker_chart.dart';
import 'package:medical24/features/health/widgets/biomarker_list.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class BodyDetailScreen extends ConsumerWidget {
  const BodyDetailScreen({super.key, required this.organId});
  final String organId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<OrganOverview>> overview = ref.watch(organOverviewProvider);
    final OrganOverview? organ = overview.value?.where((OrganOverview item) => item.id == organId).firstOrNull;
    final String title = organ?.name(Localizations.localeOf(context).languageCode) ?? context.l10n.bodyTitle;
    return Scaffold(appBar: M24DetailAppBar(title: title, parentTitle: context.l10n.bodyTitle, backTooltip: context.l10n.commonBack, onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.health)), body: overview.when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: context.l10n.bodyLoadError, onRetry: () => ref.invalidate(organOverviewProvider)), data: (_) => organ == null ? AppErrorView(message: context.l10n.bodyAreaMissing, onRetry: () => context.go(AppRoutes.health)) : BodyDetailContent(organ: organ)));
  }
}

class BodyDetailContent extends ConsumerWidget {
  const BodyDetailContent({super.key, required this.organ});
  final OrganOverview organ;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<OrganBiomarker>> biomarkers = ref.watch(organBiomarkersProvider(organ.id));
    final OrganRuleVersion? rule = ref.watch(organRuleProvider).value;
    final bool loading = ref.watch(organComputeProvider).isLoading;
    return Padding(padding: EdgeInsets.all(MediaQuery.sizeOf(context).width >= 600 ? 24 : 16), child: biomarkers.when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: context.l10n.bodyValuesError, onRetry: () => ref.invalidate(organBiomarkersProvider(organ.id))), data: (List<OrganBiomarker> values) => ListView(children: <Widget>[
      M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[M24IconTile(icon: organIcon(organ.icon), variant: organTileVariant(organ.state)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(organ.name(Localizations.localeOf(context).languageCode), style: context.m24.text.h2), Text(organ.description(Localizations.localeOf(context).languageCode), style: context.m24.text.bodySmall)]))]),
        const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: <Widget>[OrganStatusPill(state: organ.state), M24StatusPill(label: organConfidenceLabel(context, organ.confidence), variant: organ.confidence >= .8 ? M24StatusPillVariant.success : organ.confidence > 0 ? M24StatusPillVariant.warning : M24StatusPillVariant.neutral)]), const SizedBox(height: 14), OrganStressBar(value: organ.stressScore),
        if (organ.computedAt != null) ...<Widget>[const SizedBox(height: 8), Text(context.l10n.bodyCalculatedOn(DateFormat.yMMMd(Localizations.localeOf(context).languageCode).add_Hm().format(organ.computedAt!.toLocal())), style: context.m24.text.caption)],
        const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 8, children: <Widget>[M24Button(label: context.l10n.bodyHistory, icon: LucideIcons.history, variant: M24ButtonVariant.outlinePrimary, onPressed: () => context.push(AppRoutes.bodyOrganHistory(organ.id))), M24Button(label: context.l10n.bodyRefresh, icon: LucideIcons.refreshCw, variant: M24ButtonVariant.outline, loading: loading, onPressed: loading ? null : () async { await ref.read(organComputeProvider.notifier).refresh(); ref.invalidate(organBiomarkersProvider(organ.id)); })])
      ])), const SizedBox(height: 24), M24SectionHeader(title: context.l10n.bodyAreaValues), const SizedBox(height: 12),
      for (final OrganBiomarker value in values.where((OrganBiomarker item) => item.isPresent)) ...<Widget>[OrganBiomarkerCard(biomarker: value), const SizedBox(height: 12)],
      for (final OrganBiomarker value in values.where((OrganBiomarker item) => !item.isPresent)) ...<Widget>[MissingBiomarkerRow(biomarker: value), const SizedBox(height: 8)],
      if (values.isEmpty) M24EmptyState(icon: LucideIcons.chartNoAxesColumn, title: context.l10n.bodyNoMappedValues, message: context.l10n.bodyEmptyMessage, actionLabel: context.l10n.healthValuesUploadReport, onAction: () => AddDocumentSheet.show(context)),
      const SizedBox(height: 24), M24Disclaimer(phoneText: context.l10n.disclaimerPhone, desktopText: context.l10n.disclaimerDesktop), const SizedBox(height: 12), OrganRuleNote(rule: rule), const SizedBox(height: 40)
    ])));
  }
}

class OrganBiomarkerCard extends ConsumerWidget {
  const OrganBiomarkerCard({super.key, required this.biomarker});
  final OrganBiomarker biomarker;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<BiomarkerHistoryData> history = ref.watch(healthHistoryProvider(HistoryRequest(biomarker.code, HealthPeriod.all)));
    final String language = Localizations.localeOf(context).languageCode;
    return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(biomarker.name(language), style: context.m24.text.h3), Text(formatUnit(biomarker.unit), style: context.m24.text.caption)])), if (biomarker.weight == 2) M24StatusPill(label: context.l10n.bodyEssential, variant: M24StatusPillVariant.info)]),
      const SizedBox(height: 8), Text(biomarker.latestValue == null ? context.l10n.healthValuesNoValue : formatMeasurement(biomarker.latestValue!, biomarker.unit, locale: language), style: context.m24.text.display),
      if (biomarker.latestAt != null) Text(DateFormat.yMMMd(language).format(biomarker.latestAt!.toLocal()), style: context.m24.text.caption), const SizedBox(height: 8), Align(alignment: Alignment.centerLeft, child: BiomarkerFlagChip(flag: biomarker.flag)),
      const SizedBox(height: 12), SizedBox(height: 220, child: history.when(loading: () => const AppLoadingView(), error: (_, __) => Center(child: Text(context.l10n.healthValuesError)), data: (BiomarkerHistoryData data) => BiomarkerChart(primary: data.points))),
      Align(alignment: Alignment.centerRight, child: M24Button(label: context.l10n.homeOpenHistory, icon: LucideIcons.arrowRight, variant: M24ButtonVariant.tertiary, size: M24ButtonSize.small, onPressed: () => context.push(AppRoutes.healthValue(biomarker.code))))
    ]));
  }
}

class MissingBiomarkerRow extends StatelessWidget {
  const MissingBiomarkerRow({super.key, required this.biomarker});
  final OrganBiomarker biomarker;
  @override
  Widget build(BuildContext context) => M24Card(padding: const EdgeInsets.all(12), child: Row(children: <Widget>[const M24IconTile(icon: LucideIcons.circleHelp, variant: M24IconTileVariant.neutral, small: true), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(biomarker.name(Localizations.localeOf(context).languageCode), style: context.m24.text.label), Text(context.l10n.bodyState_missing, style: context.m24.text.caption)])), M24Button(label: context.l10n.healthValuesUploadReport, icon: LucideIcons.fileUp, variant: M24ButtonVariant.tertiary, size: M24ButtonSize.small, onPressed: () => AddDocumentSheet.show(context))]));
}