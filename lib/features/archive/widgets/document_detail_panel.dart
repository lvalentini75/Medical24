import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/core/models/medical_document.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/archive/data/archive_repository.dart';
import 'package:medical24/features/archive/providers/archive_providers.dart';
import 'package:medical24/features/archive/widgets/archive_document_list.dart';
import 'package:medical24/features/archive/widgets/archive_labels.dart';
import 'package:medical24/features/analysis/widgets/document_analysis_panel.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';

class DocumentDetailPanel extends ConsumerStatefulWidget {
  const DocumentDetailPanel({
    super.key,
    required this.documentId,
    this.compact = false,
    this.onDeleted,
  });

  final String documentId;
  final bool compact;
  final VoidCallback? onDeleted;

  @override
  ConsumerState<DocumentDetailPanel> createState() => _DocumentDetailPanelState();
}

class _DocumentDetailPanelState extends ConsumerState<DocumentDetailPanel> {
  bool _editing = false;
  bool _busy = false;

  /// Shares the original: system share sheet on iOS and Android, download
  /// on the web. The file is temporary and is deleted right afterwards;
  /// no public link is ever created.
  Future<void> _share(MedicalDocument document) async {
    setState(() => _busy = true);
    final ArchiveRepository repository = ref.read(archiveRepositoryProvider);
    XFile? file;
    try {
      file = await repository.shareFile(document.id);
      if (kIsWeb) {
        await FilePicker.saveFile(
          dialogTitle: context.mounted
              ? context.l10n.t('archiveShareDocument')
              : 'Share',
          fileName: file.name,
          bytes: await file.readAsBytes(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.t('archiveDownloadReady'))));
        }
      } else {
        await SharePlus.instance.share(ShareParams(files: <XFile>[file]));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.t('archiveShareReady'))));
        }
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (file != null) await repository.disposeSharedFile(file);
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    final String language = Localizations.localeOf(context).languageCode;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppFailure.from(error, where: 'archive.detail').localized(language))));
  }

  Future<void> _delete(MedicalDocument document) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(context.l10n.t('archiveDeleteTitle')),
            content: Text(context.l10n.t('archiveDeleteBody')),
            actions: <Widget>[
              TextButton(
                  onPressed: () => dialogContext.pop(false),
                  child: Text(context.l10n.t('commonCancel'))),
              FilledButton(
                  onPressed: () => dialogContext.pop(true),
                  child: Text(context.l10n.t('archiveDeleteAction'))),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await ref.read(archiveListProvider.notifier).softDelete(document);
      ref.invalidate(archiveDocumentProvider(document.id));
      widget.onDeleted?.call();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<MedicalDocument?> value =
        ref.watch(archiveDocumentProvider(widget.documentId));
    return value.when(
      loading: () => const AppLoadingView(),
      error: (Object error, StackTrace _) => AppErrorView(
        message: AppFailure.from(error, where: 'archive.detail')
            .localized(Localizations.localeOf(context).languageCode),
        onRetry: () => ref.invalidate(archiveDocumentProvider(widget.documentId)),
      ),
      data: (MedicalDocument? document) {
        if (document == null) {
          return AppEmptyView(body: context.l10n.t('archiveDocumentMissing'));
        }
        return Column(children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: <Widget>[
              Expanded(
                child: Text(
                  document.title.isEmpty
                      ? archiveCategoryLabel(context, document.category)
                      : document.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              M24IconButton(icon: _editing ? LucideIcons.x : LucideIcons.pencil, tooltip: context.l10n.t('archiveEditMetadata'),
                onPressed: _busy ? null : () => setState(() => _editing = !_editing),
              ),
              M24IconButton(icon: M24Icons.share, tooltip: context.l10n.t('archiveShareDocument'),
                onPressed: _busy ? null : () => _share(document),
              ),
              M24IconButton(icon: LucideIcons.trash2, tooltip: context.l10n.t('archiveDeleteAction'),
                onPressed: _busy ? null : () => _delete(document),
              ),
            ]),
          ),
          const ClinicalDisclaimer(),
          const SizedBox(height: 8),
          Expanded(
            child: _editing
                ? DocumentMetadataForm(
                    document: document,
                    onSaved: () {
                      ref.invalidate(archiveDocumentProvider(document.id));
                      setState(() => _editing = false);
                    },
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: <Widget>[
                      if (!widget.compact) ...<Widget>[
                        SizedBox(height: 520, child: DocumentViewer(document: document)),
                        const SizedBox(height: 16),
                      ],
                      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                        ArchiveStatusBadge(status: document.status),
                        M24StatusPill(label: archiveCategoryLabel(context, document.category), variant: M24StatusPillVariant.neutral),
                        if (document.showsDuplicateBadge)
                          ArchiveDuplicateBadge(document: document),
                      ]),
                      const SizedBox(height: 12),
                      DocumentMetadataSummary(document: document),
                      const SizedBox(height: 20),
                      Text(context.l10n.t('analysisTitle'), style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      DocumentAnalysisPanel(document: document, compact: widget.compact),
                    ],
                  ),
          ),
          if (_busy) const LinearProgressIndicator(),
        ]);
      },
    );
  }
}

class DocumentViewer extends ConsumerWidget {
  const DocumentViewer({super.key, required this.document, this.pageController, this.onPageChanged});

  final MedicalDocument document;
  final PageController? pageController;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (document.isPdf) {
      final AsyncValue<String> url = ref.watch(archiveSignedUrlProvider(document.originalPath));
      return url.when(
        loading: () => const AppLoadingView(),
        error: (Object error, StackTrace _) =>
            AppErrorView(message: context.l10n.t('commonErrorTitle')),
        data: (String value) => ClipRRect(
            borderRadius: BorderRadius.circular(12), child: PdfViewer.uri(Uri.parse(value))),
      );
    }
    final int count = document.pageCount < 1 ? 1 : document.pageCount;
    return PageView.builder(
      controller: pageController,
      onPageChanged: onPageChanged,
      itemCount: count,
      itemBuilder: (BuildContext context, int index) => DocumentImagePage(
          path: document.pagePath(index + 1), pageNumber: index + 1, pageCount: count),
    );
  }
}

class DocumentImagePage extends ConsumerWidget {
  const DocumentImagePage(
      {super.key, required this.path, required this.pageNumber, required this.pageCount});

  final String path;
  final int pageNumber;
  final int pageCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String> url = ref.watch(archiveSignedUrlProvider(path));
    return Semantics(
      label: context.l10n.t('archivePageLabel', args: <String, String>{
        'current': '$pageNumber',
        'total': '$pageCount',
      }),
      child: url.when(
        loading: () => const AppLoadingView(),
        error: (Object error, StackTrace _) =>
            AppErrorView(message: context.l10n.t('commonErrorTitle')),
        data: (String value) => InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.network(value, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class DocumentMetadataSummary extends StatelessWidget {
  const DocumentMetadataSummary({super.key, required this.document});

  final MedicalDocument document;

  @override
  Widget build(BuildContext context) {
    final String locale = Localizations.localeOf(context).languageCode;
    final List<MapEntry<String, String>> values = <MapEntry<String, String>>[
      if (document.documentDate != null)
        MapEntry<String, String>('archiveDocumentDate', DateFormat.yMMMd(locale).format(document.documentDate!)),
      if ((document.doctorName ?? '').isNotEmpty)
        MapEntry<String, String>('archiveDoctor', document.doctorName!),
      if ((document.facilityName ?? '').isNotEmpty)
        MapEntry<String, String>('archiveFacility', document.facilityName!),
      if ((document.episode ?? '').isNotEmpty)
        MapEntry<String, String>('archiveEpisode', document.episode!),
      if (document.tags.isNotEmpty)
        MapEntry<String, String>('archiveTags', document.tags.join(', ')),
      if ((document.notes ?? '').isNotEmpty)
        MapEntry<String, String>('archiveNotes', document.notes!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: values
          .map((MapEntry<String, String> item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text(context.l10n.t(item.key), style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 3),
                  Text(item.value),
                ]),
              ))
          .toList(growable: false),
    );
  }
}

class DocumentMetadataForm extends ConsumerStatefulWidget {
  const DocumentMetadataForm({super.key, required this.document, required this.onSaved});

  final MedicalDocument document;
  final VoidCallback onSaved;

  @override
  ConsumerState<DocumentMetadataForm> createState() => _DocumentMetadataFormState();
}

class _DocumentMetadataFormState extends ConsumerState<DocumentMetadataForm> {
  late final TextEditingController _title;
  late final TextEditingController _doctor;
  late final TextEditingController _facility;
  late final TextEditingController _tags;
  late final TextEditingController _episode;
  late final TextEditingController _notes;
  late DocumentCategory _category;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.document.title);
    _doctor = TextEditingController(text: widget.document.doctorName);
    _facility = TextEditingController(text: widget.document.facilityName);
    _tags = TextEditingController(text: widget.document.tags.join(', '));
    _episode = TextEditingController(text: widget.document.episode);
    _notes = TextEditingController(text: widget.document.notes);
    _category = widget.document.category;
    _date = widget.document.documentDate ?? DateTime.now();
  }

  @override
  void dispose() {
    for (final TextEditingController controller
        in <TextEditingController>[_title, _doctor, _facility, _tags, _episode, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(archiveListProvider.notifier).updateMetadata(
            widget.document.id,
            title: _title.text.trim(),
            category: _category,
            documentDate: _date,
            doctorName: _doctor.text.trim(),
            facilityName: _facility.text.trim(),
            tags: _tags.text.split(',').map((String value) => value.trim()).where((String value) => value.isNotEmpty).toList(),
            episode: _episode.text.trim(),
            notes: _notes.text.trim(),
          );
      widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(controller: _title, decoration: InputDecoration(labelText: context.l10n.t('archiveTitleField'))),
          const SizedBox(height: 12),
          DropdownButtonFormField<DocumentCategory>(
            initialValue: _category,
            decoration: InputDecoration(labelText: context.l10n.t('archiveCategoryField')),
            items: DocumentCategory.values.map((DocumentCategory value) => DropdownMenuItem<DocumentCategory>(value: value, child: Text(archiveCategoryLabel(context, value)))).toList(),
            onChanged: (DocumentCategory? value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final DateTime? value = await showDatePicker(context: context, firstDate: DateTime(1900), lastDate: DateTime.now(), initialDate: _date);
              if (value != null) setState(() => _date = value);
            },
             icon: const Icon(M24Icons.calendar),
            label: Text(DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(_date)),
          ),
          const SizedBox(height: 12),
          TextField(controller: _doctor, decoration: InputDecoration(labelText: context.l10n.t('archiveDoctor'))),
          const SizedBox(height: 12),
          TextField(controller: _facility, decoration: InputDecoration(labelText: context.l10n.t('archiveFacility'))),
          const SizedBox(height: 12),
          TextField(controller: _tags, decoration: InputDecoration(labelText: context.l10n.t('archiveTags'))),
          const SizedBox(height: 12),
          TextField(controller: _episode, decoration: InputDecoration(labelText: context.l10n.t('archiveEpisode'))),
          const SizedBox(height: 12),
          TextField(controller: _notes, maxLines: 4, decoration: InputDecoration(labelText: context.l10n.t('archiveNotes'))),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: Text(context.l10n.t('commonSave'))),
        ],
      );
}