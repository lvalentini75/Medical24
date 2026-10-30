import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medical24/core/models/user_profile.dart';
import 'package:medical24/core/providers/app_providers.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/archive/widgets/add_document_sheet.dart';
import 'package:medical24/features/health/prevention/data/prevention_models.dart';
import 'package:medical24/features/health/prevention/providers/prevention_providers.dart';
import 'package:medical24/features/health/prevention/widgets/prevention_widgets.dart';
import 'package:medical24/features/health/widgets/health_navigation.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class PreventionScreen extends ConsumerStatefulWidget {
  const PreventionScreen({super.key});
  @override
  ConsumerState<PreventionScreen> createState() => _PreventionScreenState();
}

class _PreventionScreenState extends ConsumerState<PreventionScreen> {
  PreventionTab tab = PreventionTab.controls;
  @override
  Widget build(BuildContext context) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    if (GoRouterState.of(context).uri.queryParameters['tab'] == 'risks') tab = PreventionTab.risks;
    return SectionPage(title: context.l10n.preventionTitle, subtitle: context.l10n.preventionSubtitle, action: Tooltip(message: context.l10n.preventionComingSoon, child: M24Button(label: context.l10n.preventionAddReminder, icon: M24Icons.plus, onPressed: null)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      HealthSectionNavigation(selected: HealthSection.prevention, desktop: desktop), const SizedBox(height: 12),
      M24Tabs(labels: <String>[context.l10n.preventionTabControls, context.l10n.preventionTabRisks, context.l10n.preventionTabHistory], index: tab.index, onChanged: (int value) => setState(() => tab = PreventionTab.values[value])), const SizedBox(height: 16),
      Expanded(child: ref.watch(preventionSnapshotProvider).when(data: (PreventionSnapshot data) => PreventionContent(snapshot: data, tab: tab), loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: context.l10n.preventionLoadError, onRetry: () => ref.invalidate(preventionSnapshotProvider)))),
    ]));
  }
}

class PreventionContent extends StatelessWidget {
  const PreventionContent({super.key, required this.snapshot, required this.tab});
  final PreventionSnapshot snapshot;
  final PreventionTab tab;
  @override
  Widget build(BuildContext context) => switch (tab) { PreventionTab.controls => PreventionControls(snapshot: snapshot), PreventionTab.risks => PreventionRisks(snapshot: snapshot), PreventionTab.history => PreventionHistory(snapshot: snapshot) };
}

class PreventionControls extends ConsumerWidget {
  const PreventionControls({super.key, required this.snapshot});
  final PreventionSnapshot snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    final Widget upcoming = PreventionUpcoming(snapshot: snapshot);
    if (!desktop) return ListView(padding: const EdgeInsets.only(bottom: 24), children: <Widget>[upcoming, const SizedBox(height: 24), PreventionRegistered(items: snapshot.recommendations.where((PreventionRecommendation item) => item.status == RecommendationStatus.done).toList()), const SizedBox(height: 24), PreventionRiskSummary(snapshot: snapshot), const SizedBox(height: 20), M24Disclaimer(phoneText: context.l10n.disclaimerPhone, desktopText: context.l10n.disclaimerDesktop)]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Expanded(flex: 5, child: SingleChildScrollView(child: upcoming)), const SizedBox(width: 24),
      Expanded(flex: 4, child: SingleChildScrollView(child: Column(children: <Widget>[PreventionRegistered(items: snapshot.recommendations.where((PreventionRecommendation item) => item.status == RecommendationStatus.done).toList()), const SizedBox(height: 20), PreventionLinkExam(onUploaded: (String id) async { final PreventionRecommendation? target = snapshot.open.firstOrNull; if (target != null) await ref.read(preventionActionsProvider).complete(target.id, documentId: id); })]))), const SizedBox(width: 24),
      Expanded(flex: 3, child: SingleChildScrollView(child: Column(children: <Widget>[PreventionProfile(questionnaireComplete: snapshot.questionnaire.completed), const SizedBox(height: 20), PreventionRiskSummary(snapshot: snapshot), const SizedBox(height: 20), M24Disclaimer(phoneText: context.l10n.disclaimerPhone, desktopText: context.l10n.disclaimerDesktop)]))),
    ]);
  }
}

class PreventionUpcoming extends ConsumerWidget {
  const PreventionUpcoming({super.key, required this.snapshot});
  final PreventionSnapshot snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    M24SectionHeader(title: context.l10n.preventionNextSteps), const SizedBox(height: 12),
    if (snapshot.open.isEmpty) M24Card(child: Text(context.l10n.preventionNoUpcoming)) else ...snapshot.open.map((PreventionRecommendation item) => Padding(padding: const EdgeInsets.only(bottom: 12), child: PreventionRecommendationRow(item: item, onComplete: () => _complete(context, ref, item), onDismiss: () => _dismiss(context, ref, item)))),
    if (!snapshot.questionnaire.completed) M24Card(selectable: true, onTap: () => context.push(AppRoutes.preventionQuestionnaire), child: Row(children: <Widget>[const M24IconTile(icon: M24Icons.review, variant: M24IconTileVariant.warning), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(context.l10n.preventionInitialQuestionnaires, style: context.m24.text.title), Text(context.l10n.preventionStatusComplete, style: context.m24.text.bodySmall)])), Icon(M24Icons.chevronRight, color: context.m24.colors.inkMuted)])),
  ]);

  Future<void> _complete(BuildContext context, WidgetRef ref, PreventionRecommendation item) async {
    final CompletionChoice? choice = await showModalBottomSheet<CompletionChoice>(context: context, builder: (_) => const RecommendationCompletionSheet());
    if (choice == null || !context.mounted) return;
    String? document;
    if (choice == CompletionChoice.document) document = await AddDocumentSheet.show(context);
    if ((choice == CompletionChoice.document && document == null) || !context.mounted) return;
    await ref.read(preventionActionsProvider).complete(item.id, documentId: document);
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref, PreventionRecommendation item) async {
    final String? reason = await showModalBottomSheet<String>(context: context, isScrollControlled: true, builder: (_) => const RecommendationDismissSheet());
    if (reason == null) return;
    await ref.read(preventionActionsProvider).dismiss(item.id, reason: reason.isEmpty ? null : reason);
  }
}

enum CompletionChoice { document, withoutDocument }

class RecommendationCompletionSheet extends StatelessWidget {
  const RecommendationCompletionSheet({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(context.l10n.preventionExamDone, style: context.m24.text.h2), const SizedBox(height: 16), M24Button(label: context.l10n.preventionUploadDocument, icon: M24Icons.upload, onPressed: () => context.pop(CompletionChoice.document)), const SizedBox(height: 8), M24Button(label: context.l10n.preventionDoneWithoutDocument, variant: M24ButtonVariant.outline, onPressed: () => context.pop(CompletionChoice.withoutDocument))])));
}

class RecommendationDismissSheet extends StatefulWidget {
  const RecommendationDismissSheet({super.key});
  @override
  State<RecommendationDismissSheet> createState() => _RecommendationDismissSheetState();
}

class _RecommendationDismissSheetState extends State<RecommendationDismissSheet> {
  final TextEditingController controller = TextEditingController();
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(context.l10n.preventionIgnoreTitle, style: context.m24.text.h2), const SizedBox(height: 8), TextField(controller: controller, maxLines: 3, decoration: InputDecoration(labelText: context.l10n.preventionIgnoreReason)), const SizedBox(height: 16), M24Button(label: context.l10n.preventionIgnore, variant: M24ButtonVariant.destructiveOutline, onPressed: () => context.pop(controller.text.trim()))]));
}

class PreventionRegistered extends StatelessWidget {
  const PreventionRegistered({super.key, required this.items});
  final List<PreventionRecommendation> items;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[M24SectionHeader(title: context.l10n.preventionRegistered), const SizedBox(height: 12), M24Card(padding: EdgeInsets.zero, child: items.isEmpty ? Padding(padding: const EdgeInsets.all(16), child: Text(context.l10n.preventionNoRegistered)) : Column(children: <Widget>[for (final PreventionRecommendation item in items) M24ListRow(icon: M24Icons.confirm, iconVariant: M24IconTileVariant.success, title: preventionRecommendationText(context.l10n, item.titleKey), subtitle: item.completedAt == null ? context.l10n.preventionNotAvailable : DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(item.completedAt!), onTap: item.documentId == null ? null : () => context.push(AppRoutes.archiveDocument(item.documentId!)))]))]);
}

class PreventionLinkExam extends StatelessWidget {
  const PreventionLinkExam({super.key, required this.onUploaded});
  final ValueChanged<String> onUploaded;
  @override
  Widget build(BuildContext context) => M24Card(tint: M24CardTint.primary, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(context.l10n.preventionLinkExam, style: context.m24.text.h2), const SizedBox(height: 8), Text(context.l10n.preventionDropZone, style: context.m24.text.bodySmall), const SizedBox(height: 12), M24Button(label: context.l10n.preventionExamDone, icon: M24Icons.upload, variant: M24ButtonVariant.outlinePrimary, onPressed: () async { final String? id = await AddDocumentSheet.show(context); if (id != null) onUploaded(id); })]));
}

class PreventionProfile extends ConsumerWidget {
  const PreventionProfile({super.key, required this.questionnaireComplete});
  final bool questionnaireComplete;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserProfile? profile = ref.watch(myProfileProvider).value;
    final int? age = profile?.birthDate == null ? null : DateTime.now().year - profile!.birthDate!.year;
    return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(context.l10n.preventionProfileTitle, style: context.m24.text.h2), const SizedBox(height: 10), Text(age == null ? context.l10n.preventionAgeMissing : context.l10n.preventionAgeValue(age), style: context.m24.text.body), Text(questionnaireComplete ? context.l10n.preventionLifestyleComplete : context.l10n.preventionLifestyleMissing, style: context.m24.text.bodySmall), if (!questionnaireComplete) Padding(padding: const EdgeInsets.only(top: 12), child: M24Button(label: context.l10n.preventionCompleteQuestionnaire, variant: M24ButtonVariant.secondary, onPressed: () => context.push(AppRoutes.preventionQuestionnaire)))]));
  }
}

class PreventionRiskSummary extends StatelessWidget {
  const PreventionRiskSummary({super.key, required this.snapshot});
  final PreventionSnapshot snapshot;
  @override
  Widget build(BuildContext context) => M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    Text(context.l10n.preventionRisksQuestionnaires, style: context.m24.text.h2),
    const SizedBox(height: 8),
    for (final RiskFamily family in RiskFamily.values) InkWell(
      onTap: () => context.go('${AppRoutes.prevention}?tab=risks'),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: <Widget>[
        Icon(preventionFamilyIcon(family), size: 20, color: context.m24.colors.primary), const SizedBox(width: 8),
        Expanded(child: Text(preventionFamilyTitle(context.l10n, family))),
        if (snapshot.scoreFor(family) != null) riskPill(context, snapshot.scoreFor(family)!.level) else Text(context.l10n.preventionDataIncomplete, style: context.m24.text.caption),
      ])),
    ),
  ]));
}

class PreventionRisks extends StatelessWidget {
  const PreventionRisks({super.key, required this.snapshot});
  final PreventionSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final int columns = width >= 1200 ? 3 : width >= 600 ? 2 : 1;
    return GridView.count(crossAxisCount: columns, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: columns == 1 ? .82 : .72, padding: const EdgeInsets.only(bottom: 24), children: <Widget>[for (final RiskFamily family in RiskFamily.values) RiskCard(family: family, score: snapshot.scoreFor(family), history: snapshot.riskHistory, names: snapshot.biomarkerNames, onHistory: () => showDialog<void>(context: context, builder: (_) => RiskHistoryDialog(family: family, points: snapshot.riskHistory)), onCompleteData: () => family == RiskFamily.kidney ? context.go(AppRoutes.archive) : context.push(AppRoutes.preventionQuestionnaire))]);
  }
}

class RiskHistoryDialog extends StatelessWidget {
  const RiskHistoryDialog({super.key, required this.family, required this.points});
  final RiskFamily family;
  final List<RiskScore> points;
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text('${context.l10n.preventionHistoryTitle} · ${preventionFamilyTitle(context.l10n, family)}'), content: SizedBox(width: 520, child: RiskHistoryChart(family: family, points: points)), actions: <Widget>[M24Button(label: context.l10n.commonClose, variant: M24ButtonVariant.tertiary, onPressed: () => context.pop())]);
}

class PreventionHistory extends ConsumerWidget {
  const PreventionHistory({super.key, required this.snapshot});
  final PreventionSnapshot snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(padding: const EdgeInsets.only(bottom: 24), children: <Widget>[Text(context.l10n.preventionHistoryRecommendations, style: context.m24.text.h2), const SizedBox(height: 12), if (snapshot.closed.isEmpty) M24Card(child: Text(context.l10n.preventionNoHistory)) else ...snapshot.closed.map((PreventionRecommendation item) => Padding(padding: const EdgeInsets.only(bottom: 8), child: M24Card(child: Row(children: <Widget>[M24IconTile(icon: item.status == RecommendationStatus.done ? M24Icons.confirm : M24Icons.discard, variant: item.status == RecommendationStatus.done ? M24IconTileVariant.success : M24IconTileVariant.neutral), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(preventionRecommendationText(context.l10n, item.titleKey), style: context.m24.text.title), Text(item.dismissReason?.isNotEmpty == true ? item.dismissReason! : DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(item.completedAt ?? item.dismissedAt ?? DateTime.now()), style: context.m24.text.bodySmall)])), if (item.status == RecommendationStatus.dismissed) M24Button(label: context.l10n.preventionReopen, size: M24ButtonSize.small, variant: M24ButtonVariant.tertiary, onPressed: () => ref.read(preventionActionsProvider).reopen(item.id))])))), const SizedBox(height: 20), Text(context.l10n.preventionRiskTimeline, style: context.m24.text.h2), const SizedBox(height: 12), for (final RiskFamily family in RiskFamily.values) Padding(padding: const EdgeInsets.only(bottom: 12), child: M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(preventionFamilyTitle(context.l10n, family), style: context.m24.text.title), const SizedBox(height: 8), RiskHistoryChart(family: family, points: snapshot.riskHistory)]))), M24Disclaimer(phoneText: context.l10n.disclaimerPhone, desktopText: context.l10n.disclaimerDesktop)]);
}