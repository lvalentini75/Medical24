import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/features/health/widgets/biomarker_chart.dart';
import 'package:medical24/features/health/widgets/biomarker_list.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Full history workspace for one biomarker using the M24 data-display kit.
class BiomarkerHistory extends ConsumerStatefulWidget {
  const BiomarkerHistory({super.key, required this.code, this.desktopWorkspace = false});
  final String code;
  final bool desktopWorkspace;

  @override
  ConsumerState<BiomarkerHistory> createState() => _BiomarkerHistoryState();
}

class _BiomarkerHistoryState extends ConsumerState<BiomarkerHistory> {
  HealthPeriod _period = HealthPeriod.all;
  String? _comparisonCode;
  BiomarkerEpisode? _selectedEpisode;

  @override
  void didUpdateWidget(covariant BiomarkerHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _comparisonCode = null;
      _selectedEpisode = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<BiomarkerSummary>> catalog = ref.watch(healthCatalogProvider);
    final AsyncValue<BiomarkerHistoryData> history = ref.watch(healthHistoryProvider(HistoryRequest(widget.code, _period)));
    return history.when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: context.l10n.t('healthValuesError'), onRetry: () => ref.invalidate(healthHistoryProvider(HistoryRequest(widget.code, _period)))), data: (BiomarkerHistoryData data) {
      final BiomarkerSummary? summary = catalog.value?.where((BiomarkerSummary item) => item.code == widget.code).firstOrNull;
      final BiomarkerHistoryData? comparison = _comparisonCode == null ? null : ref.watch(healthHistoryProvider(HistoryRequest(_comparisonCode!, _period))).value;
      return BiomarkerHistoryContent(summary: summary, data: data, period: _period, comparisonCode: _comparisonCode, comparisonData: comparison, catalog: catalog.value ?? const <BiomarkerSummary>[], selectedEpisode: _selectedEpisode, desktopWorkspace: widget.desktopWorkspace, onPeriod: (HealthPeriod value) => setState(() { _period = value; _selectedEpisode = null; }), onComparison: (String? value) => setState(() => _comparisonCode = value), onEpisode: (BiomarkerEpisode value) => setState(() => _selectedEpisode = identical(_selectedEpisode, value) ? null : value));
    });
  }
}

/// Presentational history content shared by phone, tablet, and desktop.
class BiomarkerHistoryContent extends StatelessWidget {
  const BiomarkerHistoryContent({super.key, required this.summary, required this.data, required this.period, required this.comparisonCode, required this.comparisonData, required this.catalog, required this.selectedEpisode, required this.desktopWorkspace, required this.onPeriod, required this.onComparison, required this.onEpisode});
  final BiomarkerSummary? summary;
  final BiomarkerHistoryData data;
  final HealthPeriod period;
  final String? comparisonCode;
  final BiomarkerHistoryData? comparisonData;
  final List<BiomarkerSummary> catalog;
  final BiomarkerEpisode? selectedEpisode;
  final bool desktopWorkspace;
  final ValueChanged<HealthPeriod> onPeriod;
  final ValueChanged<String?> onComparison;
  final ValueChanged<BiomarkerEpisode> onEpisode;

  @override
  Widget build(BuildContext context) {
    final String language = Localizations.localeOf(context).languageCode;
    final BiomarkerStats stats = data.stats;
    final String unit = summary?.unit ?? data.points.firstOrNull?.unit ?? '';
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      if (!desktopWorkspace) Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(summary?.name(language) ?? data.points.firstOrNull?.code ?? '', style: context.m24.text.h2), const SizedBox(height: 4), Text(stats.latestValue == null ? context.l10n.t('healthValuesNoValue') : formatMeasurement(stats.latestValue!, unit, locale: language), style: context.m24.text.display), if (stats.latestAt != null) Text(DateFormat.yMMMd(language).format(stats.latestAt!.toLocal()), style: context.m24.text.bodySmall)])),
        if (stats.changeFromPrevious != null) ChangeBadge(change: stats.changeFromPrevious!),
      ]),
      if (!desktopWorkspace) const SizedBox(height: 16),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: M24Segmented<HealthPeriod>(segments: <M24Segment<HealthPeriod>>[
        M24Segment<HealthPeriod>(value: HealthPeriod.all, label: context.l10n.t('healthPeriodAll')),
        M24Segment<HealthPeriod>(value: HealthPeriod.year, label: context.l10n.t('healthPeriodYear')),
        M24Segment<HealthPeriod>(value: HealthPeriod.days90, label: context.l10n.t('healthPeriod90')),
        M24Segment<HealthPeriod>(value: HealthPeriod.days30, label: context.l10n.t('healthPeriod30')),
      ], selected: period, onChanged: onPeriod)),
      const SizedBox(height: 12),
      M24Card(child: SizedBox(height: desktopWorkspace ? 280 : 300, child: BiomarkerChart(primary: data.points, comparison: comparisonData?.points, selectedEpisode: selectedEpisode))),
      const SizedBox(height: 12),
      StatisticsGrid(stats: stats, unit: unit),
      if (!desktopWorkspace) ...<Widget>[
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerLeft, child: PopupMenuButton<String>(onSelected: (String value) => onComparison(value), itemBuilder: (_) => catalog.where((BiomarkerSummary item) => item.code != summary?.code && item.valueCount > 0).map((BiomarkerSummary item) => PopupMenuItem<String>(value: item.code, child: Text(item.name(language)))).toList(growable: false), child: M24FilterChip(label: comparisonCode == null ? context.l10n.t('healthCompareWith') : catalog.where((BiomarkerSummary item) => item.code == comparisonCode).firstOrNull?.name(language) ?? comparisonCode!, selected: comparisonCode != null, hasMenu: true))),
        const SizedBox(height: 24),
        M24SectionHeader(title: context.l10n.t('healthEpisodesTitle')),
        if (data.episodes.isEmpty) Text(context.l10n.t('healthEpisodesEmpty'), style: context.m24.text.bodySmall) else SizedBox(height: 128, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: data.episodes.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (BuildContext context, int index) => EpisodeCard(episode: data.episodes[index], selected: identical(selectedEpisode, data.episodes[index]), onTap: () => onEpisode(data.episodes[index])))),
      ],
      const SizedBox(height: 24),
      M24SectionHeader(title: desktopWorkspace ? context.l10n.t('healthMeasurementHistory') : context.l10n.t('healthTableTitle')),
      const SizedBox(height: 8),
      BiomarkerValuesTable(points: sortedBiomarkerPoints(data.points, descending: true), compact: desktopWorkspace),
      if (!desktopWorkspace) ...<Widget>[const SizedBox(height: 24), const ClinicalDisclaimer(), if (MediaQuery.sizeOf(context).width < 600) const SizedBox(height: 80)],
    ]));
  }
}

class ChangeBadge extends StatelessWidget {
  const ChangeBadge({super.key, required this.change});
  final double change;
  @override
  Widget build(BuildContext context) => M24StatusPill(label: formatValue(change, locale: Localizations.localeOf(context).languageCode, signed: true), variant: change > 0 ? M24StatusPillVariant.warning : M24StatusPillVariant.success);
}

class StatisticsGrid extends StatelessWidget {
  const StatisticsGrid({super.key, required this.stats, required this.unit});
  final BiomarkerStats stats;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final String language = Localizations.localeOf(context).languageCode;
    String value(double? number, {bool signed = false}) => number == null ? '–' : formatMeasurement(number, unit, locale: language, signed: signed);
    final List<(String, String)> items = <(String, String)>[(context.l10n.t('healthStatsLatest'), value(stats.latestValue)), (context.l10n.t('healthStatsAverage'), value(stats.average)), (context.l10n.t('healthStatsMinimum'), value(stats.minimum)), (context.l10n.t('healthStatsMaximum'), value(stats.maximum)), (context.l10n.t('healthStatsChange'), value(stats.changeFromPrevious, signed: true))];
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
      final int columns = constraints.maxWidth >= 700 ? 5 : constraints.maxWidth >= 480 ? 3 : 2;
      final double width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(spacing: 8, runSpacing: 8, children: items.map(((String, String) item) => SizedBox(width: width, child: M24Card(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(item.$1, style: context.m24.text.caption), const SizedBox(height: 4), Text(item.$2, style: context.m24.text.title, maxLines: 1, overflow: TextOverflow.ellipsis)])))).toList(growable: false));
    });
  }
}

class EpisodeCard extends StatelessWidget {
  const EpisodeCard({super.key, required this.episode, required this.selected, required this.onTap});
  final BiomarkerEpisode episode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DateFormat date = DateFormat.yMMMd(Localizations.localeOf(context).languageCode);
    final ObservationFlag flag = switch (episode.level) { 'critical_low' => ObservationFlag.criticalLow, 'critical_high' => ObservationFlag.criticalHigh, 'below' => ObservationFlag.below, 'above' => ObservationFlag.above, _ => ObservationFlag.unknown };
    return SizedBox(width: 245, child: M24Card(selectable: true, selected: selected, onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[BiomarkerFlagChip(flag: flag), const SizedBox(height: 8), Text('${date.format(episode.start)} - ${episode.end == null ? context.l10n.t('healthEpisodeOngoing') : date.format(episode.end!)}', style: context.m24.text.bodySmall, maxLines: 2), Text(context.l10n.t('healthEpisodeCount', args: <String, String>{'count': '${episode.items.length}'}), style: context.m24.text.caption)])));
  }
}

class BiomarkerValuesTable extends StatelessWidget {
  const BiomarkerValuesTable({super.key, required this.points, this.compact = false});
  final List<BiomarkerPoint> points;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String language = Localizations.localeOf(context).languageCode;
    final DateFormat date = DateFormat.yMd(language);
    final DateFormat dateTime = DateFormat.yMd(language).add_Hm();
    final Map<String, int> dayCounts = <String, int>{};
    for (final BiomarkerPoint point in points) {
      final DateTime local = point.at.toLocal();
      final String key = '${local.year}-${local.month}-${local.day}';
      dayCounts[key] = (dayCounts[key] ?? 0) + 1;
    }
    final List<String> columns = compact ? <String>[context.l10n.t('healthTableDate'), context.l10n.t('healthTableValue'), context.l10n.t('healthTableDocument')] : <String>[context.l10n.t('healthTableDate'), context.l10n.t('healthTableValue'), context.l10n.t('healthTableStatus')];
    final List<List<Widget>> rows = points.map((BiomarkerPoint point) {
      final DateTime local = point.at.toLocal();
      final String key = '${local.year}-${local.month}-${local.day}';
      final String dateLabel = dayCounts[key]! > 1 ? dateTime.format(local) : date.format(local);
      final String document = point.documentName?.trim().isNotEmpty == true ? point.documentName! : point.documentId == null ? context.l10n.t('healthOrigin_${point.origin.value}') : context.l10n.t('healthOpenReport');
      return compact
        ? <Widget>[Text(dateLabel), Text(formatMeasurement(point.value, point.unit, rawValue: point.valueRaw, locale: language)), Row(children: <Widget>[const Icon(LucideIcons.fileText, size: 18), const SizedBox(width: 6), Flexible(child: Tooltip(message: document, child: Text(document, maxLines: 2, overflow: TextOverflow.ellipsis)))])]
        : <Widget>[Text(dateLabel), Text(formatMeasurement(point.value, point.unit, rawValue: point.valueRaw, locale: language)), BiomarkerFlagChip(flag: point.flag)];
    }).toList(growable: false);
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: ConstrainedBox(constraints: BoxConstraints(minWidth: compact ? 680 : 560), child: M24Table(columns: columns, rows: rows, fixedColumnWidth: compact ? 150 : 112, onRowTap: (int index) { final String? id = points[index].documentId; if (id != null) context.push(AppRoutes.archiveDocument(id)); })));
  }
}

List<BiomarkerPoint> sortedBiomarkerPoints(List<BiomarkerPoint> points, {bool descending = false}) {
  final List<BiomarkerPoint> sorted = List<BiomarkerPoint>.of(points);
  sorted.sort((BiomarkerPoint a, BiomarkerPoint b) {
    int result = a.at.compareTo(b.at);
    if (result == 0) result = (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    if (result == 0) result = a.id.compareTo(b.id);
    return descending ? -result : result;
  });
  return sorted;
}