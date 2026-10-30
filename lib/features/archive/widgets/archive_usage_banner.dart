import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/features/archive/data/archive_repository.dart';
import 'package:medical24/features/archive/providers/archive_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// "N of 30 documents", read from `document_usage()`.
///
/// The count never comes from the length of the loaded page: the plan is a
/// server-side fact and the list is paginated.
class ArchiveUsageCounter extends ConsumerWidget {
  const ArchiveUsageCounter({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DocumentUsage> usage = ref.watch(archiveUsageProvider);
    return usage.when(
      loading: () => Text(context.l10n.t('archiveUsageLoading'),
          style: style ?? Theme.of(context).textTheme.bodySmall),
      error: (Object _, StackTrace __) => const SizedBox.shrink(),
      data: (DocumentUsage value) => Text(
        context.l10n.t('archiveUsageCounter', args: <String, String>{
          'used': '${value.used}',
          'max': '${value.max}',
        }),
        style: style ?? Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

/// Shown instead of the upload button once the plan limit is reached.
/// The paywall itself belongs to P09: here we only explain and point to
/// Settings.
class ArchiveLimitNotice extends StatelessWidget {
  const ArchiveLimitNotice({super.key, required this.usage});

  final DocumentUsage usage;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(context.l10n.t('archiveLimitReachedTitle'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            context.l10n.t('archiveLimitReachedBody',
                args: <String, String>{'max': '${usage.max}'}),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.settings),
              icon: const Icon(Icons.settings_outlined),
              label: Text(context.l10n.t('archiveOpenSettings')),
            ),
          ),
        ],
      ),
    );
  }
}
