import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/health/body/data/body_models.dart';
import 'package:medical24/features/health/body/providers/body_providers.dart';
import 'package:medical24/features/health/body/widgets/body_widgets.dart';
import 'package:medical24/features/health/widgets/biomarker_history.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class BodyHistoryScreen extends ConsumerStatefulWidget {
  const BodyHistoryScreen({super.key, required this.organId});
  final String organId;
  @override
  ConsumerState<BodyHistoryScreen> createState() => _BodyHistoryScreenState();
}

class _BodyHistoryScreenState extends ConsumerState<BodyHistoryScreen> {
  String? selectedCode;
  @override
  Widget build(BuildContext context) {
    final OrganOverview? organ = ref.watch(organOverviewProvider).value?.where((OrganOverview item) => item.id == widget.organId).firstOrNull;
    final String title = organ?.name(Localizations.localeOf(context).languageCode) ?? context.l10n.bodyHistory;
    return Scaffold(appBar: M24DetailAppBar(title: title, parentTitle: context.l10n.bodyHistory, backTooltip: context.l10n.commonBack, onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.bodyOrgan(widget.organId))), body: Padding(padding: EdgeInsets.all(MediaQuery.sizeOf(context).width >= 600 ? 24 : 16), child: _content(context)));
  }

  Widget _content(BuildContext context) {
    final AsyncValue<List<OrganHistoryEntry>> history = ref.watch(organHistoryProvider(widget.organId));
    final AsyncValue<OrganComparison> comparison = ref.watch(organComparisonProvider(widget.organId));
    final AsyncValue<List<OrganEpisode>> episodes = ref.watch(organEpisodesProvider(widget.organId));
    final AsyncValue<List<OrganBiomarker>> biomarkers = ref.watch(organBiomarkersProvider(widget.organId));
    if (history.isLoading || comparison.isLoading || episodes.isLoading || biomarkers.isLoading) return const AppLoadingView();
    if (history.hasError || comparison.hasError || episodes.hasError || biomarkers.hasError) return AppErrorView(message: context.l10n.bodyHistoryError, onRetry: () { ref.invalidate(organHistoryProvider(widget.organId)); ref.invalidate(organComparisonProvider(widget.organId)); ref.invalidate(organEpisodesProvider(widget.organId)); ref.invalidate(organBiomarkersProvider(widget.organId)); });
    final List<OrganBiomarker> values = biomarkers.requireValue.where((OrganBiomarker item) => item.isPresent).toList(growable: false);
    if (selectedCode == null && values.isNotEmpty) selectedCode = values.first.code;
    return ListView(children: <Widget>[
      M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(context.l10n.bodyComparison, style: context.m24.text.h2), const SizedBox(height: 16), OrganComparisonRow(comparison: comparison.requireValue)])), const SizedBox(height: 12),
      OrganEpisodesCard(episodes: episodes.requireValue), const SizedBox(height: 24), M24SectionHeader(title: context.l10n.bodyStateTimeline), const SizedBox(height: 10),
      if (history.requireValue.isEmpty) Text(context.l10n.bodyHistoryEmpty, style: context.m24.text.bodySmall) else OrganHistoryTimeline(entries: history.requireValue, biomarkers: biomarkers.requireValue),
      const SizedBox(height: 24), M24SectionHeader(title: context.l10n.bodyBiomarkerCharts), const SizedBox(height: 10),
      if (values.isEmpty) Text(context.l10n.bodyNoPresentValues, style: context.m24.text.bodySmall) else ...<Widget>[PopupMenuButton<String>(onSelected: (String value) => setState(() => selectedCode = value), itemBuilder: (_) => values.map((OrganBiomarker item) => PopupMenuItem<String>(value: item.code, child: Text(item.name(Localizations.localeOf(context).languageCode)))).toList(growable: false), child: Align(alignment: Alignment.centerLeft, child: M24FilterChip(label: values.where((OrganBiomarker item) => item.code == selectedCode).firstOrNull?.name(Localizations.localeOf(context).languageCode) ?? selectedCode!, selected: true, hasMenu: true))), const SizedBox(height: 12), SizedBox(height: 620, child: BiomarkerHistory(code: selectedCode!, desktopWorkspace: true))],
      const SizedBox(height: 24), M24Disclaimer(phoneText: context.l10n.disclaimerPhone, desktopText: context.l10n.disclaimerDesktop), const SizedBox(height: 40)
    ]);
  }
}