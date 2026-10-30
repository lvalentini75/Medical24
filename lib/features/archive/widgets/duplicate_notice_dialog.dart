import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/core/models/medical_document.dart';
import 'package:medical24/features/archive/providers/archive_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// "This may already be in your archive".
///
/// - "Keep both" calls `dismissDuplicate(id)`: the badge disappears and the
///   new document stays.
/// - "Open the original" calls `openOriginal(newId)`: the new copy is soft
///   deleted and the id of the original is returned to the caller.
class DuplicateNoticeDialog extends ConsumerStatefulWidget {
  const DuplicateNoticeDialog({super.key, required this.document});

  final MedicalDocument document;

  /// Returns the id of the original when the user chose to open it,
  /// otherwise null.
  static Future<String?> show(
    BuildContext context,
    WidgetRef ref,
    MedicalDocument document,
  ) =>
      showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DuplicateNoticeDialog(document: document),
      );

  @override
  ConsumerState<DuplicateNoticeDialog> createState() =>
      _DuplicateNoticeDialogState();
}

class _DuplicateNoticeDialogState extends ConsumerState<DuplicateNoticeDialog> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    try {
      final String? result = await action();
      if (mounted) context.pop(result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      final String language = Localizations.localeOf(context).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppFailure.from(error, where: 'archive.duplicate')
              .localized(language))));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(context.l10n.t('archiveDuplicateTitle')),
        content: _busy
            ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
            : Text(context.l10n.t('archiveDuplicateBody')),
        actions: <Widget>[
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                      await ref
                          .read(archiveListProvider.notifier)
                          .dismissDuplicate(widget.document.id);
                      return null;
                    }),
            child: Text(context.l10n.t('archiveKeepBoth')),
          ),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() => ref
                    .read(archiveListProvider.notifier)
                    .openOriginal(widget.document.id)),
            child: Text(context.l10n.t('archiveOpenOriginal')),
          ),
        ],
      );
}
