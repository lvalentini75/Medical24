import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/core/models/medical_document.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/features/archive/data/archive_repository.dart';
import 'package:medical24/features/archive/data/image_pipeline.dart';
import 'package:medical24/features/archive/providers/archive_providers.dart';
import 'package:medical24/features/archive/widgets/archive_labels.dart';
import 'package:medical24/features/archive/widgets/archive_usage_banner.dart';
import 'package:medical24/features/archive/widgets/duplicate_notice_dialog.dart';
import 'package:medical24/features/archive/widgets/page_crop_dialog.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/navigation.dart';

class AddDocumentSheet extends ConsumerStatefulWidget {
  const AddDocumentSheet({
    super.key,
    this.initialFiles = const <DroppedFile>[],
    this.initialPages = const <Uint8List>[],
  });

  /// Files already chosen elsewhere, e.g. dropped on the archive list
  /// (web drag-and-drop). They go through the same validation.
  final List<DroppedFile> initialFiles;

  /// Shots already taken elsewhere; they enter the multi-page flow.
  final List<Uint8List> initialPages;

  static Future<String?> show(
    BuildContext context, {
    List<DroppedFile> initialFiles = const <DroppedFile>[],
    List<Uint8List> initialPages = const <Uint8List>[],
  }) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => AddDocumentSheet(
            initialFiles: initialFiles, initialPages: initialPages),
      );

  @override
  ConsumerState<AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends ConsumerState<AddDocumentSheet> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _doctor = TextEditingController();
  final TextEditingController _facility = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _episode = TextEditingController();
  /// Whole files (PDF or single image): each one becomes its own document.
  final List<_PickedDocument> _files = <_PickedDocument>[];

  /// Camera / gallery shots: together they become one multi-page document
  /// whose original is the PDF composed on the client.
  final List<_PickedPage> _pages = <_PickedPage>[];
  DocumentCategory _category = DocumentCategory.reports;
  DateTime _date = DateTime.now();
  bool _uploading = false;
  int _completed = 0;
  int _total = 0;

  bool get _hasContent => _files.isNotEmpty || _pages.isNotEmpty;

  @override
  void initState() {
    super.initState();
    for (final DroppedFile file in widget.initialFiles) {
      _files.add(_PickedDocument(
        name: file.name,
        bytes: file.bytes,
        source: file.isPdf ? DocumentSource.pdf : DocumentSource.gallery,
      ));
    }
    for (final Uint8List page in widget.initialPages) {
      _pages.add(_PickedPage(bytes: page));
    }
    _setSuggestedTitle();
  }

  void _setSuggestedTitle() {
    if (_title.text.trim().isNotEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _title.text.isNotEmpty) return;
      _title.text = '${archiveCategoryLabel(context, _category)} ${DateFormat.yMd(Localizations.localeOf(context).languageCode).format(_date)}';
    });
  }

  @override
  void dispose() {
    for (final TextEditingController controller
        in <TextEditingController>[_title, _doctor, _facility, _tags, _episode]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCamera() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.camera);
    if (file != null) await _addPage(file);
  }

  Future<void> _pickGallery() async {
    final List<XFile> files = await _picker.pickMultiImage();
    for (final XFile file in files) {
      await _addPage(file);
    }
  }

  Future<void> _pickFiles() async {
    final List<PlatformFile> result = await FilePicker.pickFiles();
    for (final PlatformFile file in result) {
      final Uint8List bytes = await file.xFile.readAsBytes();
      _files.add(_PickedDocument(
          name: file.name,
          bytes: bytes,
          source: file.extension?.toLowerCase() == 'pdf'
              ? DocumentSource.pdf
              : DocumentSource.gallery));
    }
    if (mounted) setState(() {});
  }

  Future<void> _addPage(XFile file) async {
    final Uint8List bytes = await file.readAsBytes();
    if (mounted) setState(() => _pages.add(_PickedPage(bytes: bytes)));
  }

  void _rotatePage(int index) {
    try {
      final Uint8List rotated = ImagePipeline.rotate(_pages[index].bytes);
      setState(() => _pages[index] = _PickedPage(bytes: rotated));
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _cropPage(int index) async {
    final Uint8List? cropped =
        await PageCropDialog.show(context, _pages[index].bytes);
    if (cropped != null && mounted) {
      setState(() => _pages[index] = _PickedPage(bytes: cropped));
    }
  }

  void _rotateFile(int index) {
    try {
      final Uint8List rotated = ImagePipeline.rotate(_files[index].bytes);
      setState(() => _files[index] = _files[index].copyWith(bytes: rotated));
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    final String language = Localizations.localeOf(context).languageCode;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            AppFailure.from(error, where: 'archive.upload').localized(language))));
  }

  List<String> get _tagList => _tags.text
      .split(',')
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);

  Future<void> _upload() async {
    if (!_hasContent || _title.text.trim().isEmpty) return;
    setState(() {
      _uploading = true;
      _completed = 0;
      _total = _files.length + (_pages.isEmpty ? 0 : _pages.length + 1);
    });
    String? uploadedDocumentId;
    try {
      if (_pages.isNotEmpty) {
        final MedicalDocument document =
            await ref.read(archiveListProvider.notifier).uploadPages(
                  pages: _pages
                      .map((_PickedPage page) => page.bytes)
                      .toList(growable: false),
                  source: DocumentSource.camera,
                  title: _title.text.trim(),
                  category: _category,
                  documentDate: _date,
                  tags: _tagList,
                  doctorName: _doctor.text.trim(),
                  facilityName: _facility.text.trim(),
                  episode: _episode.text.trim(),
                  onProgress: (int done, int _) {
                    if (mounted) setState(() => _completed = done);
                  },
                );
        uploadedDocumentId = document.id;
        if (document.duplicateOf != null && mounted) {
          await _showDuplicate(document);
        }
      }

      for (final _PickedDocument file in _files) {
        MedicalDocument document =
            await ref.read(archiveListProvider.notifier).upload(
                  bytes: file.bytes,
                  originalName: file.name,
                  source: file.source,
                  title: _title.text.trim(),
                  category: _category,
                  documentDate: _date,
                  tags: _tagList,
                );
        document = await ref.read(archiveListProvider.notifier).updateMetadata(
              document.id,
              doctorName: _doctor.text.trim(),
              facilityName: _facility.text.trim(),
              episode: _episode.text.trim(),
            );
        uploadedDocumentId = document.id;
        if (mounted) setState(() => _completed++);
        if (document.duplicateOf != null && mounted) {
          await _showDuplicate(document);
        }
      }
      if (mounted) context.pop(uploadedDocumentId);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _showDuplicate(MedicalDocument document) async {
    final String? originalId =
        await DuplicateNoticeDialog.show(context, ref, document);
    if (originalId != null && mounted) {
      context.pop();
      context.push(AppRoutes.archiveDocument(originalId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.sizeOf(context).height * 0.92;
    final AsyncValue<DocumentUsage> usage = ref.watch(archiveUsageProvider);
    final bool limitReached =
        usage.hasValue && usage.requireValue.isLimitReached;
    return SizedBox(
      height: height,
      child: Column(children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          child: Row(children: <Widget>[
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(context.l10n.t('archiveAddTitle'), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                const ArchiveUsageCounter(),
              ]),
            ),
            M24IconButton(icon: LucideIcons.x, tooltip: context.l10n.t('commonClose'), onPressed: _uploading ? null : context.pop),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: <Widget>[
              if (limitReached) ...<Widget>[
                ArchiveLimitNotice(usage: usage.requireValue),
                const SizedBox(height: 16),
              ],
              M24Sheet(items: <M24SheetItem>[
                M24SheetItem(icon: LucideIcons.camera, label: context.l10n.t('archiveSourceCamera'), onTap: limitReached ? () {} : _pickCamera),
                M24SheetItem(icon: LucideIcons.images, label: context.l10n.t('archiveSourceGallery'), onTap: limitReached ? () {} : _pickGallery),
                M24SheetItem(icon: M24Icons.upload, label: context.l10n.t('archiveSourceFile'), onTap: limitReached ? () {} : _pickFiles),
              ]),
              if (!_hasContent)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text(context.l10n.t('archiveChooseSource'))),
                ),
              if (_pages.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Row(children: <Widget>[
                  Expanded(
                    child: Text(context.l10n.t('archiveMultiPageTitle'),
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Text(
                    context.l10n.t('archivePagesCount',
                        args: <String, String>{'count': '${_pages.length}'}),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ]),
                Text(context.l10n.t('archiveReorderHint'),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                SizedBox(
                  height: 148,
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    itemCount: _pages.length,
                    onReorder: (int oldIndex, int newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      setState(() => _pages.insert(newIndex, _pages.removeAt(oldIndex)));
                    },
                    itemBuilder: (BuildContext context, int index) => ReorderableDragStartListener(
                      key: ValueKey<_PickedPage>(_pages[index]),
                      index: index,
                      child: _PagePreview(
                        page: _pages[index],
                        pageNumber: index + 1,
                        onRotate: _uploading ? null : () => _rotatePage(index),
                        onCrop: _uploading ? null : () => _cropPage(index),
                        onDelete: _uploading ? null : () => setState(() => _pages.removeAt(index)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(context.l10n.t('archiveSharePdfNote'),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              if (_files.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text(context.l10n.t('archivePagesPreview'), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SizedBox(
                  height: 132,
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _files.length,
                    onReorder: (int oldIndex, int newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      setState(() => _files.insert(newIndex, _files.removeAt(oldIndex)));
                    },
                    itemBuilder: (BuildContext context, int index) => _PickedPreview(
                      key: ValueKey<_PickedDocument>(_files[index]),
                      file: _files[index],
                      onRotate: () => _rotateFile(index),
                      onDelete: () => setState(() => _files.removeAt(index)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(controller: _title, decoration: InputDecoration(labelText: context.l10n.t('archiveTitleField'), helperText: context.l10n.t('commonRequired'))),
              const SizedBox(height: 12),
              DropdownButtonFormField<DocumentCategory>(
                initialValue: _category,
                decoration: InputDecoration(labelText: context.l10n.t('archiveCategoryField')),
                items: DocumentCategory.values.map((DocumentCategory value) => DropdownMenuItem<DocumentCategory>(value: value, child: Text(archiveCategoryLabel(context, value)))).toList(),
                onChanged: _uploading ? null : (DocumentCategory? value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 12),
              M24Button(
                label: DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(_date),
                icon: M24Icons.calendar,
                variant: M24ButtonVariant.outline,
                onPressed: _uploading ? null : () async {
                  final DateTime? value = await showDatePicker(context: context, firstDate: DateTime(1900), lastDate: DateTime.now(), initialDate: _date);
                  if (value != null) setState(() => _date = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(controller: _doctor, decoration: InputDecoration(labelText: context.l10n.t('archiveDoctor'))),
              const SizedBox(height: 12),
              TextField(controller: _facility, decoration: InputDecoration(labelText: context.l10n.t('archiveFacility'))),
              const SizedBox(height: 12),
              TextField(controller: _tags, decoration: InputDecoration(labelText: context.l10n.t('archiveTagsHint'))),
              const SizedBox(height: 12),
              TextField(controller: _episode, decoration: InputDecoration(labelText: context.l10n.t('archiveEpisode'))),
            ],
          ),
        ),
        if (_uploading) ...<Widget>[
          LinearProgressIndicator(value: _total == 0 ? null : _completed / _total),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(context.l10n.t('archiveUploadProgress', args: <String, String>{'current': '$_completed', 'total': '$_total'})),
          ),
        ],
        Padding(
          padding: const EdgeInsets.all(16),
          child: M24Button(label: context.l10n.t('archiveUploadAction'), icon: M24Icons.upload, size: M24ButtonSize.large, loading: _uploading, onPressed: _uploading || limitReached || !_hasContent || _title.text.trim().isEmpty ? null : _upload),
        ),
      ]),
    );
  }
}

class _PickedPreview extends StatelessWidget {
  const _PickedPreview({super.key, required this.file, required this.onRotate, required this.onDelete});

  final _PickedDocument file;
  final VoidCallback onRotate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool pdf = file.name.toLowerCase().endsWith('.pdf');
    return Card(
      margin: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 118,
        child: Column(children: <Widget>[
          Expanded(child: pdf ? const Center(child: Icon(LucideIcons.fileText, size: 42)) : Image.memory(file.bytes, fit: BoxFit.cover, width: 118)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: <Widget>[
            IconButton(tooltip: context.l10n.t('archiveRotatePage'), onPressed: pdf ? null : onRotate, icon: const Icon(LucideIcons.rotateCw, size: 20)),
            IconButton(tooltip: context.l10n.t('archiveDeletePage'), onPressed: onDelete, icon: const Icon(LucideIcons.trash2, size: 20)),
          ]),
        ]),
      ),
    );
  }
}

class _PickedDocument {
  const _PickedDocument({required this.name, required this.bytes, required this.source});

  final String name;
  final Uint8List bytes;
  final DocumentSource source;

  _PickedDocument copyWith({Uint8List? bytes}) =>
      _PickedDocument(name: name, bytes: bytes ?? this.bytes, source: source);
}

/// One camera/gallery shot of the multi-page flow, before normalisation.
class _PickedPage {
  const _PickedPage({required this.bytes});

  final Uint8List bytes;
}

/// Thumbnail of a shot with rotate, crop and delete.
class _PagePreview extends StatelessWidget {
  const _PagePreview({
    required this.page,
    required this.pageNumber,
    required this.onRotate,
    required this.onCrop,
    required this.onDelete,
  });

  final _PickedPage page;
  final int pageNumber;
  final VoidCallback? onRotate;
  final VoidCallback? onCrop;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(right: 8),
        child: SizedBox(
          width: 126,
          child: Column(children: <Widget>[
            Expanded(
              child: Stack(fit: StackFit.expand, children: <Widget>[
                Image.memory(page.bytes, fit: BoxFit.cover),
                Positioned(
                  left: 4,
                  top: 4,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: Text('$pageNumber',
                        style: Theme.of(context).textTheme.labelSmall),
                  ),
                ),
              ]),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: <Widget>[
              IconButton(
                  tooltip: context.l10n.t('archiveRotatePage'),
                  onPressed: onRotate,
                  icon: const Icon(LucideIcons.rotateCw, size: 19)),
              IconButton(
                  tooltip: context.l10n.t('archiveCropPage'),
                  onPressed: onCrop,
                  icon: const Icon(LucideIcons.crop, size: 19)),
              IconButton(
                  tooltip: context.l10n.t('archiveDeletePage'),
                  onPressed: onDelete,
                  icon: const Icon(LucideIcons.trash2, size: 19)),
            ]),
          ]),
        ),
      );
}

/// File handed to the sheet from outside, e.g. dropped on the archive list.
class DroppedFile {
  const DroppedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  bool get isPdf => name.toLowerCase().endsWith('.pdf');
}