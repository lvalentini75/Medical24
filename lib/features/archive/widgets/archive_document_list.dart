import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:medical24/core/models/medical_document.dart';
import 'package:medical24/features/archive/providers/archive_providers.dart';
import 'package:medical24/features/archive/widgets/archive_labels.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ArchiveDocumentList extends ConsumerStatefulWidget {
  const ArchiveDocumentList({
    super.key,
    required this.documents,
    required this.onOpen,
    this.selectedId,
    this.dense = false,
  });

  final List<MedicalDocument> documents;
  final ValueChanged<MedicalDocument> onOpen;
  final String? selectedId;
  final bool dense;

  @override
  ConsumerState<ArchiveDocumentList> createState() => _ArchiveDocumentListState();
}

class _ArchiveDocumentListState extends ConsumerState<ArchiveDocumentList> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 360) {
      ref.read(archiveListProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
          controller: _scroll,
          itemCount: widget.documents.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index == widget.documents.length) {
              return const SizedBox(height: 56, child: Center(child: _LoadMoreIndicator()));
            }
            final MedicalDocument document = widget.documents[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ArchiveDocumentRow(
                document: document,
                dense: widget.dense,
                selected: widget.selectedId == document.id,
                onTap: () => widget.onOpen(document),
              ),
            );
          },
        );
  }
}

class _LoadMoreIndicator extends ConsumerWidget {
  const _LoadMoreIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool hasMore = ref.read(archiveListProvider.notifier).hasMore;
    return hasMore
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
        : const SizedBox.shrink();
  }
}

class ArchiveDocumentRow extends ConsumerWidget {
  const ArchiveDocumentRow({
    super.key,
    required this.document,
    required this.onTap,
    this.selected = false,
    this.dense = false,
  });

  final MedicalDocument document;
  final VoidCallback onTap;
  final bool selected;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime? date = document.documentDate ?? document.createdAt;
    final String dateLabel = date == null
        ? context.l10n.t('archiveDateUnknown')
        : DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(date);
    final M24IconTileVariant variant = switch (document.status) { DocumentStatus.needsReview || DocumentStatus.processing => M24IconTileVariant.warning, DocumentStatus.analyzed => M24IconTileVariant.success, DocumentStatus.failed => M24IconTileVariant.danger, _ => M24IconTileVariant.info };
    return Semantics(
      button: true,
      label: context.l10n.t('archiveOpenDocument', args: <String, String>{
        'title': document.title.isEmpty ? archiveCategoryLabel(context, document.category) : document.title,
      }),
      child: M24Card(selectable: true, selected: selected, onTap: onTap, padding: EdgeInsets.all(dense ? 8 : 12), child: Row(children: <Widget>[
              M24IconTile(icon: M24Icons.archive, variant: variant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      document.title.isEmpty
                          ? archiveCategoryLabel(context, document.category)
                          : document.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.m24.text.title,
                    ),
                    const SizedBox(height: 4),
                    Text('${archiveCategoryLabel(context, document.category)} · $dateLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                    if (document.showsDuplicateBadge) ...<Widget>[
                      const SizedBox(height: 4),
                      ArchiveDuplicateBadge(document: document),
                    ],
                    if (!dense && (document.doctorName ?? '').isNotEmpty)
                      Text(document.doctorName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ArchiveStatusBadge(status: document.status),
              const SizedBox(width: 6),
              Icon(M24Icons.chevronRight, size: 20, color: context.m24.colors.inkMuted),
            ])),
    );
  }
}

/// "Possible duplicate", shown only while `duplicate_dismissed_at` is null.
/// Tapping it keeps both documents and removes the label.
class ArchiveDuplicateBadge extends ConsumerWidget {
  const ArchiveDuplicateBadge({super.key, required this.document});

  final MedicalDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: context.l10n.t('archiveDuplicateDismiss'),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => ref
            .read(archiveListProvider.notifier)
            .dismissDuplicate(document.id),
        child: M24StatusPill(label: context.l10n.t('archiveDuplicateBadge'), variant: M24StatusPillVariant.warning),
      ),
    );
  }
}

class ArchiveThumbnail extends ConsumerWidget {
  const ArchiveThumbnail({super.key, required this.document, this.size = 56});

  final MedicalDocument document;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String> url = ref.watch(archiveSignedUrlProvider(document.thumbPath(1)));
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: url.when(
          data: (String value) => Image.network(value, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _DocumentIcon()),
          loading: () => ColoredBox(
              color: context.m24.colors.surfaceAlt, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (_, __) => const _DocumentIcon(),
        ),
      ),
    );
  }
}

class _DocumentIcon extends StatelessWidget {
  const _DocumentIcon();

  @override
  Widget build(BuildContext context) => ColoredBox(
      color: context.m24.colors.infoTint,
      child: Icon(LucideIcons.fileText, color: context.m24.colors.info));
}
