import 'package:flutter/material.dart';

import 'package:medical24/core/models/medical_document.dart';
import 'package:medical24/features/archive/data/archive_repository.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';

String archiveCategoryLabel(BuildContext context, DocumentCategory category) =>
    context.l10n.t('archiveCategory_${category.value}');

String archiveStatusLabel(BuildContext context, DocumentStatus status) =>
    context.l10n.t('archiveStatus_${status.value}');

String archiveSortLabel(BuildContext context, ArchiveSort sort) =>
    context.l10n.t('archiveSort_${sort.name}');

class ArchiveStatusBadge extends StatelessWidget {
  const ArchiveStatusBadge({super.key, required this.status});

  final DocumentStatus status;

  @override
  Widget build(BuildContext context) {
    return Semantics(label: archiveStatusLabel(context, status), child: M24StatusPill(label: archiveStatusLabel(context, status), variant: switch (status) { DocumentStatus.analyzed => M24StatusPillVariant.success, DocumentStatus.processing || DocumentStatus.needsReview => M24StatusPillVariant.warning, DocumentStatus.failed => M24StatusPillVariant.danger, DocumentStatus.uploaded => M24StatusPillVariant.info, DocumentStatus.uploading => M24StatusPillVariant.neutral }));
  }
}