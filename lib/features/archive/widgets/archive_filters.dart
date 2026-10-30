import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/models/medical_document.dart';
import 'package:medical24/core/ui/widgets/controls.dart';
import 'package:medical24/features/archive/providers/archive_providers.dart';
import 'package:medical24/features/archive/widgets/archive_labels.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Search and live archive filters, adapted to phone and desktop layouts.
class ArchiveSearchAndFilters extends ConsumerStatefulWidget {
  const ArchiveSearchAndFilters({super.key, this.vertical = false});
  final bool vertical;
  @override
  ConsumerState<ArchiveSearchAndFilters> createState() => _ArchiveSearchAndFiltersState();
}

class _ArchiveSearchAndFiltersState extends ConsumerState<ArchiveSearchAndFilters> {
  late final TextEditingController _search;
  bool _showMore = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(archiveFilterProvider).search ?? '');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ArchiveFilter filter = ref.watch(archiveFilterProvider);
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    final AsyncValue<List<int>> years = ref.watch(archiveYearsProvider);
    final Widget search = M24SearchField(controller: _search, hintText: context.l10n.t('archiveSearchHint'), onChanged: ref.read(archiveFilterProvider.notifier).setSearch);
    final List<int> availableYears = years.hasValue ? years.requireValue : const <int>[];
    final Widget year = PopupMenuButton<int?>(onSelected: ref.read(archiveFilterProvider.notifier).setYear, itemBuilder: (_) => <PopupMenuEntry<int?>>[PopupMenuItem<int?>(value: null, child: Text(context.l10n.t('archiveAllYears'))), ...availableYears.map((value) => PopupMenuItem<int?>(value: value, child: Text('$value')))], child: M24FilterChip(label: filter.year?.toString() ?? context.l10n.t('archiveYear'), selected: filter.year != null, hasMenu: true));
    if (desktop) {
      return Row(children: <Widget>[
        Expanded(child: search),
        const SizedBox(width: 12),
        PopupMenuButton<DocumentCategory?>(onSelected: ref.read(archiveFilterProvider.notifier).setCategory, itemBuilder: (_) => <PopupMenuEntry<DocumentCategory?>>[PopupMenuItem<DocumentCategory?>(value: null, child: Text(context.l10n.t('archiveAllCategories'))), ...DocumentCategory.values.map((value) => PopupMenuItem<DocumentCategory?>(value: value, child: Text(archiveCategoryLabel(context, value))))], child: M24FilterChip(label: filter.category == null ? context.l10n.t('archiveAllCategories') : archiveCategoryLabel(context, filter.category!), selected: filter.category != null, hasMenu: true)),
        const SizedBox(width: 8), year,
        const SizedBox(width: 8), M24FilterChip(label: context.l10n.t('archiveFilterNeedsReview'), selected: filter.status == DocumentStatus.needsReview, icon: LucideIcons.fileCheck, onSelected: (selected) => ref.read(archiveFilterProvider.notifier).setStatus(selected ? DocumentStatus.needsReview : null)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      search,
      const SizedBox(height: 12),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: <Widget>[
        M24FilterChip(label: context.l10n.t('archiveAll'), selected: filter.isEmpty, onSelected: (_) => ref.read(archiveFilterProvider.notifier).reset()),
        const SizedBox(width: 8), year,
        const SizedBox(width: 8), M24FilterChip(label: context.l10n.t('archiveFilters'), selected: !filter.isEmpty && filter.year == null, icon: LucideIcons.slidersHorizontal, hasMenu: true, onSelected: (_) => setState(() => _showMore = !_showMore)),
      ])),
      if (_showMore) ...<Widget>[const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
        M24FilterChip(label: context.l10n.t('archiveFilterNeedsReview'), selected: filter.status == DocumentStatus.needsReview, icon: LucideIcons.fileCheck, onSelected: (selected) => ref.read(archiveFilterProvider.notifier).setStatus(selected ? DocumentStatus.needsReview : null)),
        ...DocumentCategory.values.map((category) => M24FilterChip(label: archiveCategoryLabel(context, category), selected: filter.category == category, onSelected: (selected) => ref.read(archiveFilterProvider.notifier).setCategory(selected ? category : null))),
      ])],
    ]);
  }
}