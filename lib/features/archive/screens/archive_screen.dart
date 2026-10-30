import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/core/models/medical_document.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/theme/app_theme.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/core/widgets/detail_app_bar.dart';
import 'package:medical24/features/archive/providers/archive_providers.dart';
import 'package:medical24/features/archive/data/archive_repository.dart';
import 'package:medical24/features/archive/widgets/add_document_sheet.dart';
import 'package:medical24/features/archive/widgets/archive_document_list.dart';
import 'package:medical24/features/archive/widgets/archive_drop_target.dart';
import 'package:medical24/features/archive/widgets/archive_filters.dart';
import 'package:medical24/features/archive/widgets/archive_usage_banner.dart';
import 'package:medical24/features/archive/widgets/document_detail_panel.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';
import 'package:medical24/core/ui/widgets/data_display.dart';
import 'package:medical24/features/analysis/widgets/document_analysis_panel.dart';
import 'package:medical24/features/archive/widgets/archive_labels.dart';

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  String? _selectedId;
  int _selectedIndex = -1;
  final FocusNode _keyboardFocus = FocusNode();

  @override
  void dispose() {
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _select(MedicalDocument document, List<MedicalDocument> documents, bool desktop) {
    if (!desktop) {
      context.push(AppRoutes.archiveDocument(document.id));
      return;
    }
    setState(() {
      _selectedId = document.id;
      _selectedIndex = documents.indexWhere((MedicalDocument item) => item.id == document.id);
    });
    _keyboardFocus.requestFocus();
  }

  KeyEventResult _onKey(KeyEvent event, List<MedicalDocument> documents) {
    if (event is! KeyDownEvent || documents.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, documents.length - 1);
        _selectedId = documents[_selectedIndex].id;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex <= 0 ? 0 : _selectedIndex - 1);
        _selectedId = documents[_selectedIndex].id;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && _selectedId != null) {
      context.push(AppRoutes.archiveDocument(_selectedId!));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete && _selectedIndex >= 0) {
      _confirmDelete(documents[_selectedIndex]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _confirmDelete(MedicalDocument document) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(context.l10n.t('archiveDeleteTitle')),
            content: Text(context.l10n.t('archiveDeleteBody')),
            actions: <Widget>[
              TextButton(onPressed: () => dialogContext.pop(false), child: Text(context.l10n.t('commonCancel'))),
              FilledButton(onPressed: () => dialogContext.pop(true), child: Text(context.l10n.t('archiveDeleteAction'))),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(archiveListProvider.notifier).softDelete(document);
    if (mounted) setState(() {
      _selectedId = null;
      _selectedIndex = -1;
    });
  }

  void _openSheet({List<DroppedFile> files = const <DroppedFile>[]}) =>
      AddDocumentSheet.show(context, initialFiles: files);

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<MedicalDocument>> documents = ref.watch(archiveListProvider);
    final AsyncValue<DocumentUsage> usage = ref.watch(archiveUsageProvider);
    final bool limitReached = usage.hasValue && usage.requireValue.isLimitReached;
    final double width = MediaQuery.sizeOf(context).width;
    final bool desktop = AppBreakpoints.isDesktop(width);
    return SectionPage(
      title: context.l10n.t('archiveTitle'),
      subtitle: usage.hasValue
          ? context.l10n.t(desktop ? 'archiveDesktopSubtitle' : 'archiveDocumentCount', args: <String, String>{
              'count': '${usage.requireValue.used}',
            })
          : null,
      showDisclaimer: true,
      constrainWidth: true,
      action: M24Button(label: context.l10n.t(desktop ? 'archiveUploadDocument' : 'archiveUploadShort'), icon: M24Icons.upload, variant: desktop ? M24ButtonVariant.outlinePrimary : M24ButtonVariant.primary, onPressed: limitReached ? null : () => _openSheet()),
      child: documents.when(
        loading: () => const AppLoadingView(),
        error: (Object error, StackTrace _) => AppErrorView(
          message: AppFailure.from(error, where: 'archive.list')
              .localized(Localizations.localeOf(context).languageCode),
          onRetry: ref.read(archiveListProvider.notifier).refresh,
        ),
        data: (List<MedicalDocument> values) {
          if (values.isEmpty && ref.read(archiveFilterProvider).isEmpty) {
            return AppEmptyView(
              icon: Icons.document_scanner_outlined,
              body: context.l10n.t('archiveEmptySuggestion'),
              action: OutlinedButton.icon(
                onPressed: limitReached ? null : () => _openSheet(),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(context.l10n.t('archiveAddAction')),
              ),
            );
          }
          if (desktop) {
            final MedicalDocument? selected = _selectedId == null ? null : values.cast<MedicalDocument?>().firstWhere((item) => item?.id == _selectedId, orElse: () => null);
            return Focus(
              focusNode: _keyboardFocus,
              onKeyEvent: (_, KeyEvent event) => _onKey(event, values),
              child: Column(children: <Widget>[
                const ArchiveSearchAndFilters(),
                const SizedBox(height: 20),
                Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  Expanded(flex: 4, child: M24Card(padding: const EdgeInsets.all(12), child: values.isEmpty ? AppEmptyView(body: context.l10n.t('archiveNoResults')) : SingleChildScrollView(child: M24Table(columns: <String>[context.l10n.t('homeTableDocument'), context.l10n.t('homeTableDate'), context.l10n.t('homeTableStatus')], selectedRow: _selectedIndex < 0 ? null : _selectedIndex, onRowTap: (index) => _select(values[index], values, true), rows: values.map((document) => <Widget>[Text(document.title.isEmpty ? archiveCategoryLabel(context, document.category) : document.title, overflow: TextOverflow.ellipsis), Text(document.documentDate == null ? context.l10n.t('archiveDateUnknown') : DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(document.documentDate!)), ArchiveStatusBadge(status: document.status)]).toList())))),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: selected == null ? M24Card(child: AppEmptyView(body: context.l10n.t('archiveSelectDocument'))) : ArchiveOriginalWorkspace(document: selected)),
                  const SizedBox(width: 20),
                  Expanded(flex: 3, child: selected == null ? M24Card(child: AppEmptyView(body: context.l10n.t('archiveSelectDocument'))) : M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[Text(context.l10n.t('archiveExtractedData'), style: context.m24.text.h2), const SizedBox(height: 12), Expanded(child: SingleChildScrollView(child: DocumentAnalysisPanel(document: selected, compact: false)))]))),
                ])),
              ]),
            );
          }
          return Column(children: <Widget>[
            const ArchiveSearchAndFilters(),
            const SizedBox(height: 12),
            if (limitReached) ...<Widget>[
              ArchiveLimitNotice(usage: usage.requireValue),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: ArchiveDropTarget(
                onFiles: (List<DroppedFile> files) => _openSheet(files: files),
                child: values.isEmpty
                    ? AppEmptyView(body: context.l10n.t('archiveNoResults'))
                    : ArchiveDocumentList(
                        documents: values,
                        onOpen: (MedicalDocument value) => _select(value, values, false),
                      ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// Original report preview in the center column of the desktop archive.
class ArchiveOriginalWorkspace extends StatefulWidget {
  const ArchiveOriginalWorkspace({super.key, required this.document});
  final MedicalDocument document;
  @override
  State<ArchiveOriginalWorkspace> createState() => _ArchiveOriginalWorkspaceState();
}

class _ArchiveOriginalWorkspaceState extends State<ArchiveOriginalWorkspace> {
  final PageController _pages = PageController();
  int _page = 0;
  @override
  void dispose() { _pages.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final int count = widget.document.pageCount < 1 ? 1 : widget.document.pageCount;
    return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Row(children: <Widget>[
        Expanded(child: Text(context.l10n.t('archiveOriginal'), style: context.m24.text.h2)),
        M24IconButton(icon: M24Icons.chevronLeft, tooltip: context.l10n.t('archivePreviousPage'), onPressed: _page == 0 ? null : () => _pages.previousPage(duration: const Duration(milliseconds: 180), curve: Curves.easeOut)),
        Text(context.l10n.t('archivePageLabel', args: <String, String>{'current': '${_page + 1}', 'total': '$count'}), style: context.m24.text.caption),
        M24IconButton(icon: M24Icons.chevronRight, tooltip: context.l10n.t('archiveNextPage'), onPressed: _page + 1 >= count ? null : () => _pages.nextPage(duration: const Duration(milliseconds: 180), curve: Curves.easeOut)),
      ]),
      const SizedBox(height: 12),
      Expanded(child: ColoredBox(color: context.m24.colors.surfaceAlt, child: Padding(padding: const EdgeInsets.all(16), child: DocumentViewer(document: widget.document, pageController: _pages, onPageChanged: (value) => setState(() => _page = value))))),
      const SizedBox(height: 12),
      Align(alignment: Alignment.centerRight, child: M24Button(label: context.l10n.t('archiveOpenFullscreen'), icon: M24Icons.archive, variant: M24ButtonVariant.tertiary, onPressed: () => context.push(AppRoutes.archiveDocument(widget.document.id)))),
    ]));
  }
}

class ArchiveDocumentScreen extends StatelessWidget {
  const ArchiveDocumentScreen({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: DetailAppBar(title: context.l10n.t('archiveDocumentDetail'), parentLabel: context.l10n.t('archiveTitle'), parentRoute: AppRoutes.archive),
        body: DocumentDetailPanel(
          documentId: documentId,
          onDeleted: () => context.canPop() ? context.pop() : context.go(AppRoutes.archive),
        ),
      );
}