import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/features/health/widgets/biomarker_chart.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

enum BiomarkerListGroup { favorites, essentials, all }

/// Searchable catalog rendered as rich cards on phone and compact rows on desktop.
class BiomarkerList extends ConsumerStatefulWidget {
  const BiomarkerList({super.key, required this.selectedCode, this.desktop = false, this.showDisclaimer = false, this.onSelected});
  final String? selectedCode;
  final bool desktop;
  final bool showDisclaimer;
  final ValueChanged<String>? onSelected;

  @override
  ConsumerState<BiomarkerList> createState() => _BiomarkerListState();
}

class _BiomarkerListState extends ConsumerState<BiomarkerList> {
  BiomarkerListGroup _group = BiomarkerListGroup.all;
  bool _onlyWithValues = true;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<BiomarkerSummary>> catalog = ref.watch(healthCatalogProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      M24SearchField(hintText: context.l10n.t('healthValuesSearch'), onChanged: (String value) => setState(() => _query = value.trim().toLowerCase())),
      const SizedBox(height: 12),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: <Widget>[
        M24FilterChip(label: context.l10n.t('healthValuesAll'), selected: _group == BiomarkerListGroup.all, onSelected: (_) => setState(() => _group = BiomarkerListGroup.all)),
        const SizedBox(width: 8),
        M24FilterChip(label: context.l10n.t('healthValuesFavorites'), selected: _group == BiomarkerListGroup.favorites, icon: LucideIcons.star, onSelected: (_) => setState(() => _group = BiomarkerListGroup.favorites)),
        const SizedBox(width: 8),
        M24FilterChip(label: context.l10n.t('healthValuesEssentials'), selected: _group == BiomarkerListGroup.essentials, onSelected: (_) => setState(() => _group = BiomarkerListGroup.essentials)),
      ])),
      CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, dense: true, title: Text(context.l10n.t('healthValuesOnlyWithValues'), style: context.m24.text.label), value: _onlyWithValues, onChanged: (bool? value) => setState(() => _onlyWithValues = value ?? true)),
      Expanded(child: catalog.when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: context.l10n.t('healthValuesError'), onRetry: () => ref.invalidate(healthCatalogProvider)), data: _buildCatalog)),
    ]);
  }

  Widget _buildCatalog(List<BiomarkerSummary> rows) {
    final String language = Localizations.localeOf(context).languageCode;
    final List<BiomarkerSummary> visible = rows.where((BiomarkerSummary item) {
      if (_onlyWithValues && item.valueCount == 0) return false;
      if (_group == BiomarkerListGroup.favorites && !item.favorite) return false;
      if (_group == BiomarkerListGroup.essentials && !item.essential) return false;
      return _query.isEmpty || item.name(language).toLowerCase().contains(_query);
    }).toList(growable: false);
    if (visible.isEmpty) return M24EmptyState(icon: M24Icons.health, title: context.l10n.t('healthValuesEmptyTitle'), message: context.l10n.t('healthValuesEmptyBody'), actionLabel: context.l10n.t('healthValuesUploadReport'), onAction: () => context.go(AppRoutes.archive));
    return ListView.separated(padding: EdgeInsets.only(bottom: widget.showDisclaimer ? 80 : 0), itemCount: visible.length + (widget.showDisclaimer ? 1 : 0), separatorBuilder: (_, __) => SizedBox(height: widget.desktop ? 8 : 12), itemBuilder: (BuildContext context, int index) {
      if (index == visible.length) return const ClinicalDisclaimer();
      final BiomarkerSummary item = visible[index];
      if (!widget.desktop && item.latestValue != null && (item.favorite || item.essential)) return BiomarkerValueCard(biomarker: item);
      return BiomarkerListRow(biomarker: item, selected: item.code == widget.selectedCode, desktop: widget.desktop, onSelected: widget.onSelected);
    });
  }
}

/// Full biomarker card used for favorites and essential measurements on phone.
class BiomarkerValueCard extends ConsumerWidget {
  const BiomarkerValueCard({super.key, required this.biomarker});
  final BiomarkerSummary biomarker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String language = Localizations.localeOf(context).languageCode;
    final AsyncValue<BiomarkerHistoryData> history = ref.watch(healthHistoryProvider(HistoryRequest(biomarker.code, HealthPeriod.year)));
    final BiomarkerPoint? latest = history.value?.points.lastOrNull;
    final bool busy = ref.watch(healthWatchControllerProvider).isLoading;
    return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        M24IconTile(icon: biomarkerCategoryIcon(biomarker)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(biomarker.name(language), style: context.m24.text.h3), Text(formatUnit(biomarker.unit), style: context.m24.text.bodySmall)])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
          Text(biomarker.latestValue == null ? context.l10n.t('healthValuesNoValue') : formatValue(biomarker.latestValue!, locale: language), style: context.m24.text.display),
          if (biomarker.latestAt != null) Text(DateFormat.yMMMd(language).format(biomarker.latestAt!.toLocal()), style: context.m24.text.caption),
          if (latest?.labName != null) Tooltip(message: latest!.labName!, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(latest.labName!, style: context.m24.text.caption, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right))),
        ]),
      ]),
      const SizedBox(height: 12),
      Row(children: <Widget>[
        M24StatusPill(label: context.l10n.t('healthConfirmed'), variant: M24StatusPillVariant.success),
        const Spacer(),
        M24IconButton(icon: LucideIcons.star, tooltip: context.l10n.t(biomarker.favorite ? 'healthValuesUnfavorite' : 'healthValuesFavorite'), onPressed: busy ? null : () => ref.read(healthWatchControllerProvider.notifier).toggleWatch(biomarker, favorite: !biomarker.favorite)),
        const SizedBox(width: 4),
        M24IconButton(icon: LucideIcons.bookmark, tooltip: context.l10n.healthValuesTrackTooltip, selected: biomarker.tracked, onPressed: busy ? null : () => ref.read(healthWatchControllerProvider.notifier).toggleWatch(biomarker, tracked: !biomarker.tracked)),
      ]),
      const SizedBox(height: 12),
      SizedBox(height: 150, child: history.when(loading: () => const AppLoadingView(), error: (_, __) => Center(child: Text(context.l10n.t('healthValuesError'))), data: (BiomarkerHistoryData data) => BiomarkerChart(primary: data.points))),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 4, children: <Widget>[
        M24Button(label: context.l10n.t('homeOpenHistory'), onPressed: () => context.push(AppRoutes.healthValue(biomarker.code)), variant: M24ButtonVariant.tertiary, size: M24ButtonSize.small),
        M24Button(label: context.l10n.t('healthSourceReferences'), onPressed: latest?.documentId == null ? null : () => context.push(AppRoutes.archiveDocument(latest!.documentId!)), variant: M24ButtonVariant.tertiary, size: M24ButtonSize.small),
      ]),
    ]));
  }
}

/// Compact catalog row with favorite and tracking controls from the M24 kit.
class BiomarkerListRow extends ConsumerWidget {
  const BiomarkerListRow({super.key, required this.biomarker, required this.selected, this.desktop = false, this.onSelected});
  final BiomarkerSummary biomarker;
  final bool selected, desktop;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String language = Localizations.localeOf(context).languageCode;
    final bool busy = ref.watch(healthWatchControllerProvider).isLoading;
    final String value = biomarker.latestValue == null ? context.l10n.t('healthValuesNoValue') : formatMeasurement(biomarker.latestValue!, biomarker.unit, locale: language);
    return M24Card(selectable: true, selected: selected, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), onTap: () {
      if (onSelected != null) onSelected!(biomarker.code); else context.push(AppRoutes.healthValue(biomarker.code));
    }, child: Row(children: <Widget>[
      M24IconTile(icon: biomarkerCategoryIcon(biomarker), variant: flagTileVariant(biomarker.flag), small: desktop),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(biomarker.name(language), style: context.m24.text.title, maxLines: 1, overflow: TextOverflow.ellipsis), Text(value, style: context.m24.text.bodySmall)])),
      M24IconButton(icon: LucideIcons.star, tooltip: context.l10n.t(biomarker.favorite ? 'healthValuesUnfavorite' : 'healthValuesFavorite'), onPressed: busy ? null : () => ref.read(healthWatchControllerProvider.notifier).toggleWatch(biomarker, favorite: !biomarker.favorite)),
      M24IconButton(icon: LucideIcons.bookmark, tooltip: context.l10n.healthValuesTrackTooltip, selected: biomarker.tracked, onPressed: busy ? null : () => ref.read(healthWatchControllerProvider.notifier).toggleWatch(biomarker, tracked: !biomarker.tracked)),
      Icon(M24Icons.chevronRight, size: 20, color: context.m24.colors.inkMuted),
    ]));
  }
}

M24IconTileVariant flagTileVariant(ObservationFlag flag) => switch (flag) { ObservationFlag.within => M24IconTileVariant.success, ObservationFlag.below || ObservationFlag.above => M24IconTileVariant.warning, ObservationFlag.criticalLow || ObservationFlag.criticalHigh => M24IconTileVariant.danger, _ => M24IconTileVariant.neutral };

IconData biomarkerCategoryIcon(BiomarkerSummary biomarker) {
  final String source = '${biomarker.category} ${biomarker.nameIt} ${biomarker.nameEn}'.toLowerCase();
  if (source.contains('emat') || source.contains('hemat') || source.contains('glic') || source.contains('gluc')) return LucideIcons.droplet;
  if (source.contains('lipid') || source.contains('colesterol') || source.contains('cholesterol') || source.contains('pression') || source.contains('pressure')) return LucideIcons.heart;
  if (source.contains('enzim') || source.contains('enzyme') || source.contains('funzional') || source.contains('function')) return LucideIcons.activity;
  return LucideIcons.flaskConical;
}

class BiomarkerFlagChip extends StatelessWidget {
  const BiomarkerFlagChip({super.key, required this.flag, this.hasValue = true});
  final ObservationFlag flag;
  final bool hasValue;

  @override
  Widget build(BuildContext context) {
    final ObservationFlag shown = hasValue ? flag : ObservationFlag.unknown;
    final M24StatusPillVariant variant = switch (shown) { ObservationFlag.within => M24StatusPillVariant.success, ObservationFlag.below || ObservationFlag.above => M24StatusPillVariant.warning, ObservationFlag.criticalLow || ObservationFlag.criticalHigh => M24StatusPillVariant.danger, _ => M24StatusPillVariant.neutral };
    return M24StatusPill(label: context.l10n.t('analysisFlag_${shown.value}'), variant: variant);
  }
}