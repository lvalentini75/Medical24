import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/features/archive/widgets/add_document_sheet.dart';
import 'package:medical24/features/health/data/alert_models.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/features/health/body/data/body_models.dart';
import 'package:medical24/features/health/body/providers/body_providers.dart';
import 'package:medical24/features/health/prevention/data/prevention_models.dart';
import 'package:medical24/features/health/prevention/providers/prevention_providers.dart';
import 'package:medical24/features/health/prevention/widgets/prevention_widgets.dart';
import 'package:medical24/features/home/data/home_models.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Responsive overview built from the live home snapshot and value history.
class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key, required this.snapshot});
  final HomeSnapshot snapshot;
  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  HealthPeriod _period = HealthPeriod.year;
  String? _selectedCode;

  HomeValue? get _selected {
    if (widget.snapshot.values.isEmpty) return null;
    return widget.snapshot.values.firstWhere((value) => value.code == _selectedCode, orElse: () => widget.snapshot.values.first);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.snapshot.isEmpty) return Center(child: M24EmptyState(icon: M24Icons.upload, title: context.l10n.t('homeEmptyTitle'), message: context.l10n.t('homeEmptyBody'), actionLabel: context.l10n.t('homeUploadFirstReport'), onAction: () => AddDocumentSheet.show(context)));
    final HomeValue? selected = _selected;
    final List<BiomarkerSummary> catalog = ref.watch(healthCatalogProvider).value ?? const <BiomarkerSummary>[];
    final bool isPhone = MediaQuery.sizeOf(context).width < 1200;
    if (selected == null) return HomePhoneDashboard(snapshot: widget.snapshot, selected: selected, history: null, catalog: catalog);
    final AsyncValue<BiomarkerHistoryData> allHistory = ref.watch(healthHistoryProvider(HistoryRequest(selected.code, HealthPeriod.all)));
    final AsyncValue<BiomarkerHistoryData> requestedHistory = ref.watch(healthHistoryProvider(HistoryRequest(selected.code, _period)));
    if (isPhone) return HomePhoneDashboard(snapshot: widget.snapshot, selected: selected, history: allHistory, catalog: catalog);
    final bool shouldUseAll = _period == HealthPeriod.year && requestedHistory.hasValue && requestedHistory.requireValue.points.length < 2;
    final HealthPeriod effectivePeriod = shouldUseAll ? HealthPeriod.all : _period;
    final AsyncValue<BiomarkerHistoryData> history = effectivePeriod == HealthPeriod.all ? allHistory : requestedHistory;
    return HomeDesktopDashboard(snapshot: widget.snapshot, selected: selected, history: history, catalog: catalog, period: effectivePeriod, onPeriodChanged: (value) => setState(() => _period = value), onValueChanged: (value) => setState(() => _selectedCode = value));
  }
}

class HomePhoneDashboard extends StatelessWidget {
  const HomePhoneDashboard({super.key, required this.snapshot, required this.selected, required this.history, required this.catalog});
  final HomeSnapshot snapshot;
  final HomeValue? selected;
  final AsyncValue<BiomarkerHistoryData>? history;
  final List<BiomarkerSummary> catalog;
  @override
  Widget build(BuildContext context) {
    final List<HomeDocument> documents = homeRecentDocuments(snapshot);
    return ListView(padding: const EdgeInsets.only(bottom: 80), children: <Widget>[
      HomeHealthCard(selected: selected, history: history, catalog: catalog),
      if (snapshot.documentsToReview.isNotEmpty) ...<Widget>[const SizedBox(height: 12), M24Banner(title: context.l10n.t('homeReviewValues', args: <String, String>{'count': '${snapshot.documentsToReview.length}'}), subtitle: homeReviewSubtitle(context, snapshot.documentsToReview.first), onTap: () => context.push(AppRoutes.analysisReview(snapshot.documentsToReview.first.id)))],
      const SizedBox(height: 12),
      const HomeOrganStatusCard(),
      const SizedBox(height: 12),
      const HomeNextControlCard(),
      const SizedBox(height: 12),
      const HomeDoctorCard(),
      const SizedBox(height: 24),
      M24SectionHeader(title: context.l10n.t('homeRecentDocuments'), actionLabel: context.l10n.t('homeAllDocuments'), onAction: () => context.go(AppRoutes.archive)),
      const SizedBox(height: 12),
      M24Card(padding: EdgeInsets.zero, child: Column(children: <Widget>[for (int i = 0; i < documents.length; i++) ...<Widget>[HomeDocumentRow(document: documents[i]), if (i < documents.length - 1) Divider(height: 1, color: context.m24.colors.divider)]])),
      const SizedBox(height: 24),
      M24Disclaimer(phoneText: context.l10n.t('disclaimerPhone'), desktopText: context.l10n.t('disclaimerDesktop')),
    ]);
  }
}

class HomeDesktopDashboard extends StatelessWidget {
  const HomeDesktopDashboard({super.key, required this.snapshot, required this.selected, required this.history, required this.catalog, required this.period, required this.onPeriodChanged, required this.onValueChanged});
  final HomeSnapshot snapshot;
  final HomeValue? selected;
  final AsyncValue<BiomarkerHistoryData>? history;
  final List<BiomarkerSummary> catalog;
  final HealthPeriod period;
  final ValueChanged<HealthPeriod> onPeriodChanged;
  final ValueChanged<String> onValueChanged;
  @override
  Widget build(BuildContext context) {
    final List<HomeDocument> documents = homeRecentDocuments(snapshot);
    return ListView(padding: EdgeInsets.zero, children: <Widget>[
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 4, crossAxisSpacing: 16, childAspectRatio: 2.25, children: <Widget>[
        M24StatTile(icon: M24Icons.archive, label: context.l10n.t('homeStatDocuments'), value: '${snapshot.counts.documents}', variant: M24IconTileVariant.info),
        M24StatTile(icon: M24Icons.chart, label: context.l10n.t('homeStatTracked'), value: '${snapshot.values.length}'),
        M24StatTile(icon: M24Icons.review, label: context.l10n.t('homeStatReview'), value: '${snapshot.documentsToReview.length}', variant: M24IconTileVariant.warning),
        const HomeNextControlTile(),
      ]),
      const SizedBox(height: 24),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Expanded(flex: 8, child: HomeValuesOverTimeCard(snapshot: snapshot, selected: selected, history: history, catalog: catalog, period: period, onPeriodChanged: onPeriodChanged, onValueChanged: onValueChanged)),
        const SizedBox(width: 24),
        Expanded(flex: 4, child: Column(children: <Widget>[const HomeOrganStatusCard(), const SizedBox(height: 24), HomeConfirmedValuesCard(values: snapshot.values, catalog: catalog), const SizedBox(height: 24), HomeTasksCard(snapshot: snapshot, catalog: catalog), const SizedBox(height: 24), const HomeDoctorCard()])),
      ]),
      const SizedBox(height: 24),
      M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        M24SectionHeader(title: context.l10n.t('homeRecentDocuments'), actionLabel: context.l10n.t('homeAllDocumentsCount', args: <String, String>{'count': '${snapshot.counts.documents}'}), onAction: () => context.go(AppRoutes.archive)),
        const SizedBox(height: 12),
        M24Table(columns: <String>[context.l10n.t('homeTableDocument'), context.l10n.t('homeTableDate'), context.l10n.t('homeTableStatus')], rows: documents.map((document) { final String title = homeDocumentTitle(context, document); return <Widget>[Row(children: <Widget>[const Icon(M24Icons.archive, size: 18), const SizedBox(width: 8), Expanded(child: Tooltip(message: title, child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis)))]), Text(homeDocumentDate(context, document)), homeDocumentPill(context, document)]; }).toList(), onRowTap: (index) => context.push(AppRoutes.archiveDocument(documents[index].id))),
      ])),
      const SizedBox(height: 24),
      M24Disclaimer(phoneText: context.l10n.t('disclaimerPhone'), desktopText: context.l10n.t('disclaimerDesktop')),
    ]);
  }
}

class HomeDoctorCard extends StatelessWidget {
  const HomeDoctorCard({super.key});

  @override
  Widget build(BuildContext context) => M24Card(
    selectable: true,
    onTap: () => context.go(AppRoutes.doctor),
    child: Row(children: <Widget>[
      const M24IconTile(icon: M24Icons.doctor, variant: M24IconTileVariant.info),
      const SizedBox(width: 12),
      Expanded(child: Text(context.l10n.t('homeYourDoctor'), style: context.m24.text.title)),
      Icon(M24Icons.chevronRight, size: 20, color: context.m24.colors.inkMuted),
    ]),
  );
}

class HomeOrganStatusCard extends ConsumerWidget {
  const HomeOrganStatusCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<OrganOverview> organs = ref.watch(organOverviewProvider).value ?? const <OrganOverview>[];
    final bool calculated = organs.any((OrganOverview item) => item.state != null);
    int count(OrganHealthState state) => organs.where((OrganOverview item) => (item.state ?? OrganHealthState.missing) == state).length;
    final String summary = calculated ? context.l10n.homeBodySummary(count(OrganHealthState.attention), count(OrganHealthState.missing), count(OrganHealthState.monitor), count(OrganHealthState.ok)) : context.l10n.t('homeHealthStatusPreparingShort');
    return M24Card(tint: M24CardTint.primary, selectable: calculated, onTap: calculated ? () => context.go(AppRoutes.health) : null, child: Row(children: <Widget>[const M24IconTile(icon: M24Icons.health), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(context.l10n.t('homeHealthStatusTitle'), style: context.m24.text.title), Text(summary, style: context.m24.text.bodySmall), if (calculated) Text(context.l10n.t('homeOpenOverview'), style: context.m24.text.label.copyWith(color: context.m24.colors.primary))])), if (calculated) Icon(M24Icons.chevronRight, size: 20, color: context.m24.colors.primary)]));
  }
}

class HomeHealthCard extends StatelessWidget {
  const HomeHealthCard({super.key, required this.selected, required this.history, required this.catalog});
  final HomeValue? selected;
  final AsyncValue<BiomarkerHistoryData>? history;
  final List<BiomarkerSummary> catalog;
  @override
  Widget build(BuildContext context) => M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    M24SectionHeader(title: context.l10n.t('homeYourHealth'), actionLabel: context.l10n.t('homeOpenOverview'), onAction: () => context.go(AppRoutes.health)),
    if (selected == null) Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(context.l10n.t('homeNoValues'))) else ...<Widget>[
      const SizedBox(height: 10), Text(context.l10n.t('homeLatestReportDate', args: <String, String>{'date': homeDate(context, selected!.effectiveAt)}), style: context.m24.text.caption),
      const SizedBox(height: 10), Text(homeBiomarkerName(context, selected!, catalog), style: context.m24.text.h3), Text(formatMeasurement(selected!.value, selected!.unit, rawValue: selected!.valueRaw, locale: Localizations.localeOf(context).languageCode), style: context.m24.text.display),
      const SizedBox(height: 12), SizedBox(height: 150, child: HomeHistoryChart(history: history, maxPoints: 6)),
    ],
  ]));
}

class HomeValuesOverTimeCard extends StatelessWidget {
  const HomeValuesOverTimeCard({super.key, required this.snapshot, required this.selected, required this.history, required this.catalog, required this.period, required this.onPeriodChanged, required this.onValueChanged});
  final HomeSnapshot snapshot;
  final HomeValue? selected;
  final AsyncValue<BiomarkerHistoryData>? history;
  final List<BiomarkerSummary> catalog;
  final HealthPeriod period;
  final ValueChanged<HealthPeriod> onPeriodChanged;
  final ValueChanged<String> onValueChanged;
  @override
  Widget build(BuildContext context) {
    final List<BiomarkerPoint> points = history?.hasValue == true ? history!.requireValue.points : const <BiomarkerPoint>[];
    return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      M24SectionHeader(title: context.l10n.t('homeValuesOverTime'), actionLabel: context.l10n.t('homeOpenHistory'), onAction: selected == null ? null : () => context.push(AppRoutes.healthValue(selected!.code))),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
        PopupMenuButton<String>(onSelected: onValueChanged, itemBuilder: (_) => snapshot.values.map((value) => PopupMenuItem<String>(value: value.code, child: Text(homeBiomarkerName(context, value, catalog)))).toList(), child: M24FilterChip(label: selected == null ? context.l10n.t('homeNoValues') : homeBiomarkerName(context, selected!, catalog), selected: true, hasMenu: true)),
        M24FilterChip(label: context.l10n.t('healthPeriod6Months'), selected: period == HealthPeriod.months6, onSelected: (_) => onPeriodChanged(HealthPeriod.months6)),
        M24FilterChip(label: context.l10n.t('healthPeriodYear'), selected: period == HealthPeriod.year, onSelected: (_) => onPeriodChanged(HealthPeriod.year)),
        M24FilterChip(label: context.l10n.t('healthPeriodAll'), selected: period == HealthPeriod.all, onSelected: (_) => onPeriodChanged(HealthPeriod.all)),
      ]),
      const SizedBox(height: 18), SizedBox(height: 240, child: HomeHistoryChart(history: history)), const SizedBox(height: 16), HomeValueStats(points: points),
    ]));
  }
}

class HomeHistoryChart extends StatelessWidget {
  const HomeHistoryChart({super.key, required this.history, this.maxPoints});
  final AsyncValue<BiomarkerHistoryData>? history;
  final int? maxPoints;
  @override
  Widget build(BuildContext context) {
    if (history == null || history!.isLoading) return const Center(child: CircularProgressIndicator());
    if (history!.hasError) return Center(child: Text(context.l10n.t('healthValuesError')));
    final List<BiomarkerPoint> allPoints = List<BiomarkerPoint>.of(history!.requireValue.points)..sort((a, b) => a.at.compareTo(b.at));
    final List<BiomarkerPoint> points = maxPoints != null && allPoints.length > maxPoints! ? allPoints.sublist(allPoints.length - maxPoints!) : allPoints;
    if (points.isEmpty) return Center(child: Text(context.l10n.t('healthHistoryNoPoints')));
    final List<FlSpot> spots = <FlSpot>[for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value)];
    final double min = points.map((point) => point.value).reduce(math.min);
    final double max = points.map((point) => point.value).reduce(math.max);
    final double padding = math.max((max - min) * .18, math.max(max.abs() * .04, 1));
    final String language = Localizations.localeOf(context).languageCode;
    return LineChart(LineChartData(minY: min - padding, maxY: max + padding, borderData: FlBorderData(show: false), gridData: M24ChartStyle.grid(context), titlesData: FlTitlesData(leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 34, getTitlesWidget: (double value, TitleMeta meta) {
      final int index = value.round();
      if (value != index || index < 0 || index >= points.length) return const SizedBox.shrink();
      return Padding(padding: EdgeInsets.only(top: index.isEven ? 0 : 10), child: Text(formatValue(points[index].value, rawValue: points[index].valueRaw, locale: language), style: context.m24.text.caption));
    })), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 32, getTitlesWidget: (double value, TitleMeta meta) {
      final int index = value.round();
      if (value != index || index < 0 || index >= points.length || index > 0 && _sameDay(points[index - 1].at, points[index].at)) return const SizedBox.shrink();
      final DateFormat date = points.length == 1 ? DateFormat.yMMMd(language) : DateFormat.Md(language);
      return Padding(padding: const EdgeInsets.only(top: 8), child: Text(date.format(points[index].at.toLocal()), style: context.m24.text.caption));
    }))), lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => context.m24.colors.ink, getTooltipItems: (spots) => spots.map((spot) {
      final BiomarkerPoint point = points[spot.spotIndex];
      return LineTooltipItem('${DateFormat.yMMMd(language).format(point.at)}\n${formatMeasurement(point.value, point.unit, rawValue: point.valueRaw, locale: language)}', context.m24.text.caption.copyWith(color: M24Colors.white));
    }).toList(growable: false))), lineBarsData: <LineChartBarData>[M24ChartStyle.line(context, spots)]));
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class HomeValueStats extends StatelessWidget {
  const HomeValueStats({super.key, required this.points});
  final List<BiomarkerPoint> points;
  @override
  Widget build(BuildContext context) {
    final BiomarkerPoint? latest = points.isEmpty ? null : points.last;
    final BiomarkerPoint? previous = points.length < 2 ? null : points[points.length - 2];
    final double? change = latest == null || previous == null || previous.value == 0 ? null : ((latest.value - previous.value) / previous.value) * 100;
    return Row(children: <Widget>[
      Expanded(child: HomeValueStat(label: context.l10n.t('healthStatsLatest'), value: latest == null ? '–' : formatMeasurement(latest.value, latest.unit, rawValue: latest.valueRaw, locale: Localizations.localeOf(context).languageCode))),
      Expanded(child: HomeValueStat(label: context.l10n.t('homePrevious'), value: previous == null ? '–' : formatMeasurement(previous.value, previous.unit, rawValue: previous.valueRaw, locale: Localizations.localeOf(context).languageCode))),
      Expanded(child: HomeValueStat(label: context.l10n.t('healthStatsChange'), value: change == null ? '–' : '${formatValue(change, locale: Localizations.localeOf(context).languageCode, signed: true)}%')),
    ]);
  }
}

class HomeValueStat extends StatelessWidget {
  const HomeValueStat({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(label, style: context.m24.text.caption), Text(value, style: context.m24.text.title)]);
}

class HomeConfirmedValuesCard extends StatelessWidget {
  const HomeConfirmedValuesCard({super.key, required this.values, required this.catalog});
  final List<HomeValue> values;
  final List<BiomarkerSummary> catalog;
  @override
  Widget build(BuildContext context) => M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    Text(context.l10n.t('homeConfirmedValues'), style: context.m24.text.h2), const SizedBox(height: 12),
    if (values.isEmpty) Text(context.l10n.t('homeNoValues')) else M24Table(columns: <String>[context.l10n.t('homeTableParameter'), context.l10n.t('analysisValueColumn'), context.l10n.t('homeTableVerification')], rows: values.take(4).map((value) => <Widget>[Text(homeBiomarkerName(context, value, catalog), maxLines: 1, overflow: TextOverflow.ellipsis), Text(formatMeasurement(value.value, value.unit, rawValue: value.valueRaw, locale: Localizations.localeOf(context).languageCode), maxLines: 1, overflow: TextOverflow.ellipsis), M24StatusPill(label: context.l10n.t('homeConfirmed'), variant: M24StatusPillVariant.success)]).toList()),
  ]));
}

class HomeTasksCard extends StatelessWidget {
  const HomeTasksCard({super.key, required this.snapshot, required this.catalog});
  final HomeSnapshot snapshot;
  final List<BiomarkerSummary> catalog;
  @override
  Widget build(BuildContext context) => Consumer(builder: (BuildContext context, WidgetRef ref, Widget? child) { final PreventionSnapshot? prevention = ref.watch(preventionSnapshotProvider).value; return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    Text(context.l10n.t('homeTasks'), style: context.m24.text.h2), const SizedBox(height: 10),
    if (snapshot.documentsToReview.isEmpty && snapshot.counts.unreadAlerts == 0 && prevention?.questionnaire.completed != false) Text(context.l10n.t('homeNothingToReview')),
    if (snapshot.documentsToReview.isNotEmpty) M24ListRow(icon: M24Icons.review, iconVariant: M24IconTileVariant.warning, title: context.l10n.t('homeReviewValues', args: <String, String>{'count': '${snapshot.documentsToReview.length}'}), subtitle: homeReviewSubtitle(context, snapshot.documentsToReview.first), onTap: () => context.push(AppRoutes.analysisReview(snapshot.documentsToReview.first.id))),
    if (snapshot.counts.unreadAlerts > 0) M24ListRow(icon: M24Icons.alerts, iconVariant: M24IconTileVariant.warning, title: context.l10n.t('homeUnreadAlerts', args: <String, String>{'count': '${snapshot.counts.unreadAlerts}'}), subtitle: snapshot.unreadAlerts.isEmpty ? context.l10n.t('homeOpenAlertCenter') : homeAlertName(context, snapshot.unreadAlerts.first, catalog), onTap: () => context.push(AppRoutes.alerts)),
    if (prevention?.questionnaire.completed == false) M24ListRow(icon: M24Icons.review, iconVariant: M24IconTileVariant.warning, title: context.l10n.homeCompleteQuestionnaires, subtitle: context.l10n.preventionStatusComplete, onTap: () => context.push(AppRoutes.preventionQuestionnaire)),
  ])); });
}

class HomeNextControlCard extends ConsumerWidget {
  const HomeNextControlCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PreventionRecommendation? item = ref.watch(preventionSnapshotProvider).value?.open.firstOrNull;
    if (item == null) return const SizedBox.shrink();
    return M24Card(selectable: true, onTap: () => context.go(AppRoutes.prevention), child: Row(children: <Widget>[const M24IconTile(icon: M24Icons.prevention), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(context.l10n.homeNextControl, style: context.m24.text.title), Text(preventionRecommendationText(context.l10n, item.titleKey), style: context.m24.text.bodySmall)])), Icon(M24Icons.chevronRight, color: context.m24.colors.inkMuted)]));
  }
}

class HomeNextControlTile extends ConsumerWidget {
  const HomeNextControlTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PreventionRecommendation? item = ref.watch(preventionSnapshotProvider).value?.open.firstOrNull;
    return M24StatTile(icon: M24Icons.prevention, label: context.l10n.homeNextControl, value: item?.dueAt == null ? context.l10n.preventionPlanShort : DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).format(item!.dueAt!), variant: item == null ? M24IconTileVariant.neutral : M24IconTileVariant.primary);
  }
}

class HomeDocumentRow extends StatelessWidget {
  const HomeDocumentRow({super.key, required this.document});
  final HomeDocument document;
  @override
  Widget build(BuildContext context) => M24ListRow(icon: M24Icons.archive, iconVariant: homeDocumentIconVariant(document.status), title: homeDocumentTitle(context, document), subtitle: homeDocumentDate(context, document), status: homeDocumentPill(context, document), onTap: () => context.push(AppRoutes.archiveDocument(document.id)));
}

List<HomeDocument> homeRecentDocuments(HomeSnapshot snapshot) {
  final List<HomeDocument> result = <HomeDocument>[if (snapshot.latestDocument != null) snapshot.latestDocument!, ...snapshot.documentsToReview];
  final Set<String> ids = <String>{};
  return result.where((document) => ids.add(document.id)).take(4).toList(growable: false);
}

String homeReviewSubtitle(BuildContext context, HomeDocument document) => context.l10n.t('homeFromReport', args: <String, String>{'date': homeDocumentDate(context, document)});
String homeDocumentTitle(BuildContext context, HomeDocument document) => document.title.isEmpty ? context.l10n.t('archiveDefaultFileName') : document.title;
String homeDocumentDate(BuildContext context, HomeDocument document) => document.documentDate == null && document.createdAt == null ? context.l10n.t('archiveDateUnknown') : homeDate(context, (document.documentDate ?? document.createdAt)!);
String homeDate(BuildContext context, DateTime value) => DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(value);
String homeBiomarkerName(BuildContext context, HomeValue value, List<BiomarkerSummary> catalog) {
  final String language = Localizations.localeOf(context).languageCode;
  return catalog.where((item) => item.code == value.code).firstOrNull?.name(language) ?? value.name(language);
}
String homeAlertName(BuildContext context, HealthAlert alert, List<BiomarkerSummary> catalog) {
  final String language = Localizations.localeOf(context).languageCode;
  return catalog.where((item) => item.code == alert.code).firstOrNull?.name(language) ?? alert.name(language);
}
M24IconTileVariant homeDocumentIconVariant(String status) => switch (status) { 'needs_review' || 'processing' => M24IconTileVariant.warning, 'analyzed' => M24IconTileVariant.success, 'failed' => M24IconTileVariant.danger, _ => M24IconTileVariant.info };
M24StatusPill homeDocumentPill(BuildContext context, HomeDocument document) => M24StatusPill(label: context.l10n.t('archiveStatus_${document.status}'), variant: switch (document.status) { 'needs_review' || 'processing' => M24StatusPillVariant.warning, 'analyzed' => M24StatusPillVariant.success, 'failed' => M24StatusPillVariant.danger, _ => M24StatusPillVariant.info });