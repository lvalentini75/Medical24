import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/health/body/data/body_models.dart';
import 'package:medical24/features/health/body/providers/body_providers.dart';
import 'package:medical24/features/health/body/widgets/body_widgets.dart';
import 'package:medical24/features/health/body/widgets/body_map.dart';
import 'package:medical24/features/health/widgets/biomarker_history.dart';
import 'package:medical24/features/health/widgets/health_navigation.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class BodyScreen extends ConsumerWidget {
  const BodyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<OrganOverview>> state = ref.watch(organOverviewProvider);
    return state.when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: context.l10n.bodyLoadError, onRetry: () => ref.invalidate(organOverviewProvider)), data: (List<OrganOverview> organs) => BodyOverviewContent(organs: organs));
  }
}

class BodyOverviewContent extends ConsumerStatefulWidget {
  const BodyOverviewContent({super.key, required this.organs});
  final List<OrganOverview> organs;
  @override
  ConsumerState<BodyOverviewContent> createState() => _BodyOverviewContentState();
}

class _BodyOverviewContentState extends ConsumerState<BodyOverviewContent> {
  bool expanded = false;
  bool phoneExploded = false;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  String? selectedCode;
  String? get selectedOrganId => ref.read(selectedOrganIdProvider);
  OrganOverview get selected => widget.organs.where((OrganOverview item) => item.id == selectedOrganId).firstOrNull ?? widget.organs.first;

  @override
  void initState() { super.initState(); _loadPreference(); }
  Future<void> _loadPreference() async { final String? value = await _storage.read(key: 'body_exploded_view'); if (mounted) setState(() => phoneExploded = value == 'true'); }
  Future<void> _setPhoneExploded(bool value) async { setState(() => phoneExploded = value); await _storage.write(key: 'body_exploded_view', value: value.toString()); }

  @override
  Widget build(BuildContext context) {
    if (widget.organs.isEmpty) return AppErrorView(message: context.l10n.bodyLoadError, onRetry: () => ref.invalidate(organOverviewProvider));
    final String? selectedId = ref.watch(selectedOrganIdProvider);
    if (selectedId != null && !widget.organs.any((OrganOverview organ) => organ.id == selectedId)) WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(selectedOrganIdProvider.notifier).state = null);
    return MediaQuery.sizeOf(context).width >= 1200 ? _desktop(context) : _compact(context);
  }

  Widget _compact(BuildContext context) {
    final bool phone = MediaQuery.sizeOf(context).width < 600;
    final bool showExploded = phone ? phoneExploded : true;
    final bool hasCalculation = widget.organs.any((OrganOverview item) => item.state != null);
    final List<OrganOverview> prioritized = List<OrganOverview>.of(widget.organs)..sort((OrganOverview a, OrganOverview b) {
      int rank(OrganOverview value) => value.state == OrganHealthState.attention ? 0 : value.state == OrganHealthState.monitor ? 1 : value.stressScore != null ? 2 : 3;
      final int byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : (b.stressScore ?? -1).compareTo(a.stressScore ?? -1);
    });
    final List<OrganOverview> shown = expanded ? widget.organs : prioritized.take(3).toList(growable: false);
    final DateTime? updated = widget.organs.map((OrganOverview item) => item.computedAt).whereType<DateTime>().fold<DateTime?>(null, (DateTime? latest, DateTime value) => latest == null || value.isAfter(latest) ? value : latest);
    return SectionPage(title: context.l10n.navMyHealth, subtitle: updated == null ? context.l10n.healthUpdatedUnavailable : context.l10n.healthUpdatedAt(DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(updated.toLocal())), showDisclaimer: false, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      const HealthSectionNavigation(selected: HealthSection.body), const SizedBox(height: 16),
      Expanded(child: ListView(children: <Widget>[
        if (phone) Row(children: <Widget>[Expanded(child: Text(context.l10n.bodyExplodedView, style: context.m24.text.label)), Switch(value: phoneExploded, onChanged: _setPhoneExploded)]),
        if (_isNeutral) M24Card(tint: M24CardTint.warning, padding: const EdgeInsets.all(12), child: Row(children: <Widget>[Icon(LucideIcons.info, size: 18, color: context.m24.colors.warning), const SizedBox(width: 8), Expanded(child: Text(context.l10n.bodyGenderNotice, style: context.m24.text.bodySmall)), M24Button(label: context.l10n.bodyOpenProfile, variant: M24ButtonVariant.tertiary, size: M24ButtonSize.small, onPressed: () => context.push(AppRoutes.settingsProfile))])),
        if (_isNeutral) const SizedBox(height: 12),
        M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          if (!hasCalculation) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(context.l10n.bodyEmptyMessage, style: context.m24.text.bodySmall)),
          if (showExploded) SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: phone ? 720 : math.max(720, MediaQuery.sizeOf(context).width - 96), child: M24ExplodedBodyMap(organs: widget.organs, selectedId: selectedOrganId, onTap: _tapOrgan, onDoubleTap: _openHistory, onEmptyTap: _clearSelection))) else Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Expanded(flex: 45, child: M24BodyMap(organs: widget.organs, selectedId: selectedOrganId, onTap: _tapOrgan, onDoubleTap: _openHistory, onEmptyTap: _clearSelection)),
            const SizedBox(width: 12),
             Expanded(flex: 55, child: Column(children: <Widget>[for (final OrganOverview organ in shown) Padding(padding: const EdgeInsets.only(bottom: 8), child: OrganListRow(organ: organ, selected: organ.id == selectedOrganId, dimmed: selectedOrganId != null && organ.id != selectedOrganId, onTap: () => _selectOrgan(organ))), if (!expanded) M24Button(label: context.l10n.bodyAllAreas, icon: LucideIcons.arrowRight, variant: M24ButtonVariant.tertiary, size: M24ButtonSize.small, onPressed: () => setState(() => expanded = true))]))
          ])
        ])),
        const SizedBox(height: 12), const BodyGradientLegend(), const SizedBox(height: 12), BodyRefreshRow(updated: updated), const SizedBox(height: 8), OrganRuleNote(rule: ref.watch(organRuleProvider).value), const SizedBox(height: 24),
        M24Disclaimer(phoneText: context.l10n.disclaimerPhone, desktopText: context.l10n.disclaimerDesktop), const SizedBox(height: 80)
      ]))
    ]));
  }

  bool get _isNeutral => !widget.organs.any((OrganOverview organ) => organ.sex == 'female' || organ.sex == 'male');

  Widget _desktop(BuildContext context) {
    final OrganOverview organ = selected;
    final AsyncValue<List<OrganBiomarker>> biomarkers = ref.watch(organBiomarkersProvider(organ.id));
    final List<OrganBiomarker> present = biomarkers.value?.where((OrganBiomarker item) => item.isPresent).toList(growable: false) ?? const <OrganBiomarker>[];
    if (present.isNotEmpty && !present.any((OrganBiomarker item) => item.code == selectedCode)) selectedCode = present.first.code;
    return SectionPage(title: context.l10n.navMyHealth, subtitle: context.l10n.bodyDesktopSubtitle, action: M24Button(label: context.l10n.homeUploadReport, icon: LucideIcons.fileUp, variant: M24ButtonVariant.outlinePrimary, onPressed: () => context.go(AppRoutes.archive)), showDisclaimer: false, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      const HealthSectionNavigation(selected: HealthSection.body, desktop: true), const SizedBox(height: 20),
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Expanded(flex: 5, child: M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(context.l10n.bodyTitle, style: context.m24.text.h2), const SizedBox(height: 8), Expanded(child: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) => constraints.maxWidth < 460 ? ListView(children: <Widget>[for (final OrganOverview item in widget.organs) Padding(padding: const EdgeInsets.only(bottom: 6), child: OrganListRow(organ: item, selected: item.id == selectedOrganId, dimmed: selectedOrganId != null && item.id != selectedOrganId, onTap: () => _selectOrgan(item)))]) : M24ExplodedBodyMap(organs: widget.organs, selectedId: selectedOrganId, onTap: _tapOrgan, onDoubleTap: _openHistory, onEmptyTap: _clearSelection))), const SizedBox(height: 8), const BodyGradientLegend(), const SizedBox(height: 8), OrganRuleNote(rule: ref.watch(organRuleProvider).value)]))),
        const SizedBox(width: 24),
        Expanded(flex: 4, child: biomarkers.when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: context.l10n.bodyValuesError, onRetry: () => ref.invalidate(organBiomarkersProvider(organ.id))), data: (_) => selectedCode == null ? M24EmptyState(icon: LucideIcons.chartNoAxesColumn, title: context.l10n.bodyNoPresentValues, message: context.l10n.bodyEmptyMessage, actionLabel: context.l10n.healthValuesUploadReport, onAction: () => context.go(AppRoutes.archive)) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[PopupMenuButton<String>(onSelected: (String value) => setState(() => selectedCode = value), itemBuilder: (_) => present.map((OrganBiomarker item) => PopupMenuItem<String>(value: item.code, child: Text(item.name(Localizations.localeOf(context).languageCode)))).toList(growable: false), child: Align(alignment: Alignment.centerLeft, child: M24FilterChip(label: present.where((OrganBiomarker item) => item.code == selectedCode).firstOrNull?.name(Localizations.localeOf(context).languageCode) ?? selectedCode!, selected: true, hasMenu: true))), const SizedBox(height: 12), Expanded(child: BiomarkerHistory(code: selectedCode!, desktopWorkspace: true))]))),
        const SizedBox(width: 24),
        Expanded(flex: 3, child: OrganDesktopSummary(organ: organ, onHistory: () => _openHistory(organ)))
      ])), const SizedBox(height: 16), M24Disclaimer(phoneText: context.l10n.disclaimerPhone, desktopText: context.l10n.disclaimerDesktop)
    ]));
  }

  void _selectOrgan(OrganOverview organ) { ref.read(selectedOrganIdProvider.notifier).state = organ.id; setState(() => selectedCode = null); }
  void _tapOrgan(OrganOverview organ) { if (selectedOrganId == organ.id) { _openOrgan(organ); } else { _selectOrgan(organ); } }
  void _clearSelection() { ref.read(selectedOrganIdProvider.notifier).state = null; setState(() => selectedCode = null); }
  void _openOrgan(OrganOverview organ) { ref.read(selectedOrganIdProvider.notifier).state = organ.id; context.push(AppRoutes.bodyOrgan(organ.id)); }
  void _openHistory(OrganOverview organ) => context.push(AppRoutes.bodyOrganHistory(organ.id));
}

class BodyRefreshRow extends ConsumerWidget {
  const BodyRefreshRow({super.key, required this.updated});
  final DateTime? updated;
  @override
  Widget build(BuildContext context, WidgetRef ref) { final bool loading = ref.watch(organComputeProvider).isLoading; return Row(children: <Widget>[Expanded(child: Text(updated == null ? context.l10n.healthUpdatedUnavailable : context.l10n.bodyUpdatedOn(DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(updated!.toLocal())), style: context.m24.text.caption)), M24Button(label: context.l10n.bodyRefresh, icon: LucideIcons.refreshCw, variant: M24ButtonVariant.outline, size: M24ButtonSize.small, loading: loading, onPressed: loading ? null : () => ref.read(organComputeProvider.notifier).refresh())]); }
}

class BodyLegend extends StatelessWidget {
  const BodyLegend({super.key});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: OrganHealthState.values.map((OrganHealthState state) => OrganStatusPill(state: state)).toList(growable: false));
}

class OrganDesktopSummary extends ConsumerWidget {
  const OrganDesktopSummary({super.key, required this.organ, required this.onHistory});
  final OrganOverview organ;
  final VoidCallback onHistory;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrganComparison? comparison = ref.watch(organComparisonProvider(organ.id)).value;
    final List<OrganEpisode> episodes = ref.watch(organEpisodesProvider(organ.id)).value ?? const <OrganEpisode>[];
    return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[M24IconTile(icon: organIcon(organ.icon), variant: organTileVariant(organ.state)), const SizedBox(height: 12), Text(organ.name(Localizations.localeOf(context).languageCode), style: context.m24.text.h2), const SizedBox(height: 8), OrganStatusPill(state: organ.state), const SizedBox(height: 12), OrganStressBar(value: organ.stressScore), const SizedBox(height: 8), M24StatusPill(label: organConfidenceLabel(context, organ.confidence), variant: organ.confidence >= .8 ? M24StatusPillVariant.success : organ.confidence > 0 ? M24StatusPillVariant.warning : M24StatusPillVariant.neutral), if (comparison != null) ...<Widget>[const SizedBox(height: 20), OrganComparisonRow(comparison: comparison)], const SizedBox(height: 16), Text(context.l10n.bodyAttentionEpisodes, style: context.m24.text.label), Text('${episodes.length}', style: context.m24.text.stat), M24Button(label: context.l10n.bodyFullHistory, icon: LucideIcons.history, variant: M24ButtonVariant.tertiary, onPressed: onHistory)]));
  }
}