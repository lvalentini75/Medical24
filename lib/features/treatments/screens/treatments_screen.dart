import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/treatments/data/treatment_models.dart';
import 'package:medical24/features/treatments/providers/treatments_providers.dart';
import 'package:medical24/features/treatments/widgets/treatment_widgets.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class TreatmentsScreen extends ConsumerStatefulWidget {
  const TreatmentsScreen({super.key, required this.queryParameters});
  final Map<String, String> queryParameters;
  @override
  ConsumerState<TreatmentsScreen> createState() => _TreatmentsScreenState();
}
class _TreatmentsScreenState extends ConsumerState<TreatmentsScreen> {
  final ScrollController scroll = ScrollController();
  late final TextEditingController search;
  Timer? debounce;
  @override
  void initState() { super.initState(); final TreatmentFilters filters = TreatmentFilters.fromQuery(widget.queryParameters); search = TextEditingController(text: filters.query); scroll.addListener(_onScroll); Future<void>.microtask(() => ref.read(treatmentSearchProvider.notifier).initialize(filters)); }
  @override
  void didUpdateWidget(covariant TreatmentsScreen oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.queryParameters.toString() != widget.queryParameters.toString()) { final TreatmentFilters filters = TreatmentFilters.fromQuery(widget.queryParameters); if (search.text != filters.query) search.text = filters.query; Future<void>.microtask(() => ref.read(treatmentSearchProvider.notifier).initialize(filters)); } }
  @override
  void dispose() { debounce?.cancel(); scroll.removeListener(_onScroll); scroll.dispose(); search.dispose(); super.dispose(); }
  void _onScroll() { if (scroll.position.extentAfter < 500) ref.read(treatmentSearchProvider.notifier).loadMore(); }
  void _update(TreatmentFilters filters) { ref.read(treatmentSearchProvider.notifier).update(filters); final Uri uri = Uri(path: AppRoutes.treatments, queryParameters: filters.toQuery().isEmpty ? null : filters.toQuery()); context.replace(uri.toString()); }
  void _query(String value) { debounce?.cancel(); debounce = Timer(const Duration(milliseconds: 400), () { if (mounted) _update(ref.read(treatmentSearchProvider).filters.copyWith(query: value.trim())); }); }
  @override
  Widget build(BuildContext context) {
    final TreatmentSearchState state = ref.watch(treatmentSearchProvider);
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    final List<TreatmentSummary> selection = ref.watch(treatmentCompareSelectionProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: !desktop && selection.isNotEmpty ? SafeArea(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: context.m24.colors.surface, border: Border(top: BorderSide(color: context.m24.colors.border))), child: M24Button(label: context.l10n.t('treatmentsSelectedCompare', args: <String, String>{'count': '${selection.length}'}), onPressed: selection.length < 2 ? null : () => context.push(AppRoutes.treatmentCompare(selection.map((item) => item.id).toList()))))) : null,
      body: SectionPage(title: context.l10n.t(desktop ? 'treatmentsTitleLong' : 'treatmentsTitle'), subtitle: desktop ? context.l10n.t('treatmentsSubtitle') : null, showDisclaimer: true, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Row(children: <Widget>[Expanded(child: M24SearchField(controller: search, hintText: context.l10n.t('treatmentsSearchHint'), onChanged: _query)), if (!desktop) ...<Widget>[const SizedBox(width: 8), M24Button(label: context.l10n.t('treatmentsFilters'), icon: M24Icons.filters, variant: M24ButtonVariant.outline, onPressed: () => _showFilters(context, state))]]),
        const SizedBox(height: 16),
        Expanded(child: desktop ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[SizedBox(width: 260, child: SingleChildScrollView(child: TreatmentFiltersPanel(filters: state.filters, facets: state.facets, onChanged: _update))), const SizedBox(width: 24), Expanded(child: TreatmentResults(state: state, controller: scroll, onFilters: () => _update(const TreatmentFilters()))), const SizedBox(width: 24), const SizedBox(width: 260, child: SingleChildScrollView(child: TreatmentComparePanel()))]) : TreatmentResults(state: state, controller: scroll, onFilters: () => _update(const TreatmentFilters()))),
      ])),
    );
  }
  Future<void> _showFilters(BuildContext context, TreatmentSearchState state) async { await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (sheetContext) => SafeArea(child: DraggableScrollableSheet(expand: false, initialChildSize: .85, maxChildSize: .95, builder: (_, controller) => SingleChildScrollView(controller: controller, padding: const EdgeInsets.all(16), child: TreatmentFiltersPanel(filters: state.filters, facets: state.facets, onChanged: (filters) { sheetContext.pop(); _update(filters); }))))); }
}

class TreatmentResults extends StatelessWidget {
  const TreatmentResults({super.key, required this.state, required this.controller, required this.onFilters});
  final TreatmentSearchState state;
  final ScrollController controller;
  final VoidCallback onFilters;
  @override
  Widget build(BuildContext context) {
    if (state.loading && state.items.isEmpty) return const AppLoadingView();
    if (state.error != null && state.items.isEmpty) return AppErrorView(message: context.l10n.t('treatmentsLoadError'), onRetry: onFilters);
    if (state.items.isEmpty) return M24EmptyState(icon: M24Icons.search, title: context.l10n.t('treatmentsEmptyTitle'), message: context.l10n.t('treatmentsEmptyBody'), actionLabel: context.l10n.t('treatmentsResetFilters'), onAction: onFilters);
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    return CustomScrollView(controller: controller, slivers: <Widget>[
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: <Widget>[Expanded(child: Row(children: <Widget>[Text(context.l10n.t('treatmentsCount', args: <String, String>{'count': '${state.total}'}), style: context.m24.text.h2), if (state.items.any((item) => item.isDemo)) ...<Widget>[const SizedBox(width: 10), M24StatusPill(label: context.l10n.t('treatmentsDemo'), variant: M24StatusPillVariant.info)]])), SizedBox(width: 190, child: DropdownButtonFormField<String>(value: state.filters.sort, decoration: InputDecoration(labelText: context.l10n.t('treatmentsSort')), items: <String>['pertinenza','rating','prezzo_asc','prezzo_desc','attesa','recenti'].map((value) => DropdownMenuItem<String>(value: value, child: Text(treatmentLabel(context, value)))).toList(), onChanged: (value) { if (value != null) context.findAncestorStateOfType<_TreatmentsScreenState>()?._update(state.filters.copyWith(sort: value)); }))]))),
      SliverGrid(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: desktop ? 3 : 1, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: desktop ? .62 : .8), delegate: SliverChildBuilderDelegate((_, index) => TreatmentCard(treatment: state.items[index]), childCount: state.items.length)),
      if (state.loadingMore) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())))
    ]);
  }
}