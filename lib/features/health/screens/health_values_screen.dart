import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/data/health_export.dart';
import 'package:medical24/features/health/data/health_repository.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/features/health/widgets/biomarker_history.dart';
import 'package:medical24/features/health/widgets/biomarker_list.dart';
import 'package:medical24/features/health/widgets/health_navigation.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Adaptive health values screen: rich phone list and 4+5+3 desktop workspace.
class HealthValuesScreen extends ConsumerWidget {
  const HealthValuesScreen({super.key, this.code});
  final String? code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double width = MediaQuery.sizeOf(context).width;
    final AsyncValue<List<BiomarkerSummary>> catalog = ref.watch(healthCatalogProvider);
    final String? selectedCode = code ?? catalog.value?.where((BiomarkerSummary item) => item.valueCount > 0).firstOrNull?.code;
    if (width >= 1200) return HealthDesktopValues(catalog: catalog, selectedCode: selectedCode);
    if (code != null) return Scaffold(appBar: M24DetailAppBar(title: context.l10n.t('analysisHistoryTitle'), parentTitle: context.l10n.t('healthValuesTitle'), backTooltip: context.l10n.t('commonBack'), onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.health)), body: Padding(padding: EdgeInsets.all(width >= 600 ? 24 : 16), child: BiomarkerHistory(code: code!)));
    final List<BiomarkerSummary> rows = catalog.value ?? const <BiomarkerSummary>[];
    final VoidCallback export = () => exportHealthCsv(ref.read(healthRepositoryProvider), rows, locale: Localizations.localeOf(context).languageCode).catchError((_) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.healthExportError))));
    return SectionPage(title: context.l10n.t('navMyHealth'), subtitle: _updatedLabel(context, rows), action: PopupMenuButton<String>(tooltip: context.l10n.healthExportCsv, icon: const Icon(LucideIcons.ellipsis), onSelected: (_) => export(), itemBuilder: (_) => <PopupMenuEntry<String>>[PopupMenuItem<String>(value: 'export', child: Text(context.l10n.healthExportCsv))]), showDisclaimer: width >= 600, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      const HealthSectionNavigation(selected: HealthSection.biomarkers),
      const SizedBox(height: 16),
      Expanded(child: BiomarkerList(selectedCode: null, showDisclaimer: width < 600)),
    ]));
  }
}

/// Desktop health workspace with catalog, history, and source details.
class HealthDesktopValues extends StatelessWidget {
  const HealthDesktopValues({super.key, required this.catalog, required this.selectedCode});
  final AsyncValue<List<BiomarkerSummary>> catalog;
  final String? selectedCode;

  @override
  Widget build(BuildContext context) => SectionPage(title: context.l10n.t('navMyHealth'), subtitle: _updatedLabel(context, catalog.value ?? const <BiomarkerSummary>[]), showDisclaimer: true, action: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[M24Button(label: context.l10n.healthExportCsv, icon: LucideIcons.fileDown, onPressed: () => exportHealthCsv(const SupabaseHealthRepository(), catalog.value ?? const <BiomarkerSummary>[], locale: Localizations.localeOf(context).languageCode), variant: M24ButtonVariant.outline), const SizedBox(width: 8), M24Button(label: context.l10n.t('homeUploadReport'), icon: M24Icons.upload, onPressed: () => context.go(AppRoutes.archive), variant: M24ButtonVariant.primary)]), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    const HealthSectionNavigation(selected: HealthSection.biomarkers, desktop: true),
    const SizedBox(height: 20),
    Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Expanded(flex: 4, child: M24Card(padding: const EdgeInsets.all(12), child: BiomarkerList(selectedCode: selectedCode, desktop: true, onSelected: (String value) => context.go(AppRoutes.healthValue(value))))),
      const SizedBox(width: 24),
      Expanded(flex: 5, child: selectedCode == null ? M24EmptyState(icon: M24Icons.chart, title: context.l10n.t('healthSelectValueTitle'), message: context.l10n.t('healthSelectValueBody'), actionLabel: context.l10n.t('healthValuesManual'), onAction: () => context.push(AppRoutes.healthValueNew)) : M24Card(child: BiomarkerHistory(code: selectedCode!, desktopWorkspace: true))),
      const SizedBox(width: 24),
      Expanded(flex: 3, child: selectedCode == null ? const SizedBox.shrink() : SelectedValuePanel(code: selectedCode!, catalog: catalog.value ?? const <BiomarkerSummary>[])),
    ])),
  ]));
}

/// Source and reference metadata for the selected desktop measurement.
class SelectedValuePanel extends ConsumerWidget {
  const SelectedValuePanel({super.key, required this.code, required this.catalog});
  final String code;
  final List<BiomarkerSummary> catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BiomarkerSummary? summary = catalog.where((BiomarkerSummary item) => item.code == code).firstOrNull;
    final AsyncValue<BiomarkerHistoryData> state = ref.watch(healthHistoryProvider(HistoryRequest(code, HealthPeriod.all)));
    return state.when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: context.l10n.t('healthValuesError'), onRetry: () => ref.invalidate(healthHistoryProvider(HistoryRequest(code, HealthPeriod.all)))), data: (BiomarkerHistoryData data) {
      final BiomarkerPoint? point = sortedBiomarkerPoints(data.points).lastOrNull;
      final String language = Localizations.localeOf(context).languageCode;
      final String reference = point == null || point.institutionalLow == null && point.institutionalHigh == null ? context.l10n.t('analysisRangeMissing') : formatRange(point.institutionalLow, point.institutionalHigh, point.unit, locale: language);
      return ListView(children: <Widget>[
        M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Text(context.l10n.t('healthSelectedValue'), style: context.m24.text.h2),
          const SizedBox(height: 16),
          Text(point == null ? context.l10n.t('healthValuesNoValue') : formatMeasurement(point.value, point.unit, rawValue: point.valueRaw, locale: language), style: context.m24.text.display),
          if (point != null) Text(DateFormat.yMMMd(language).format(point.at.toLocal()), style: context.m24.text.bodySmall),
          const SizedBox(height: 12),
          M24StatusPill(label: context.l10n.t('healthExtractionConfirmed'), variant: M24StatusPillVariant.success),
          const SizedBox(height: 20),
          Text(context.l10n.t('healthSource'), style: context.m24.text.label),
          M24Button(label: point?.documentId == null ? context.l10n.t('healthOrigin_${point?.origin.value ?? 'manual'}') : context.l10n.t('healthOpenReport'), icon: LucideIcons.fileText, onPressed: point?.documentId == null ? null : () => context.push(AppRoutes.archiveDocument(point!.documentId!)), variant: M24ButtonVariant.tertiary, size: M24ButtonSize.small),
          const Divider(),
          HealthMetadataRow(label: context.l10n.t('analysisLabName'), value: point?.labName ?? context.l10n.t('analysisRangeMissing')),
          HealthMetadataRow(label: context.l10n.t('analysisBoardRange'), value: reference),
          HealthMetadataRow(label: context.l10n.t('analysisDoctorRange'), value: point?.doctorLow == null && point?.doctorHigh == null ? context.l10n.t('healthNotSet') : formatRange(point?.doctorLow, point?.doctorHigh, point?.unit ?? summary?.unit ?? '', locale: language)),
        ])),
        const SizedBox(height: 12),
        M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(context.l10n.t('healthOtherConfirmed'), style: context.m24.text.h3), const SizedBox(height: 8), ...catalog.where((BiomarkerSummary item) => item.code != code && item.latestValue != null).take(3).map((BiomarkerSummary item) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: <Widget>[Expanded(child: Text(item.name(language), style: context.m24.text.bodySmall)), Text(formatMeasurement(item.latestValue!, item.unit, locale: language), style: context.m24.text.label)])))])),
      ]);
    });
  }
}

class HealthMetadataRow extends StatelessWidget {
  const HealthMetadataRow({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Expanded(child: Text(label, style: context.m24.text.caption)), const SizedBox(width: 8), Flexible(child: Tooltip(message: value, child: Text(value, style: context.m24.text.label, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis)))]));
}

String _updatedLabel(BuildContext context, List<BiomarkerSummary> rows) {
  final List<DateTime> dates = rows.map((BiomarkerSummary item) => item.latestAt).whereType<DateTime>().toList(growable: false);
  if (dates.isEmpty) return context.l10n.t('healthUpdatedUnavailable');
  dates.sort();
  return context.l10n.t('healthUpdatedAt', args: <String, String>{'date': DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(dates.last.toLocal())});
}