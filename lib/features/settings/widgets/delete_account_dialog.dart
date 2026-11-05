import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/features/settings/data/settings_privacy_repository.dart';
import 'package:medical24/features/settings/data/settings_privacy_localizations.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Two-step destructive confirmation for permanent account closure.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.onDelete});

  final Future<DeleteAccountResult> Function() onDelete;

  static Future<DeleteAccountResult?> show(BuildContext context, {required Future<DeleteAccountResult> Function() onDelete}) => showDialog<DeleteAccountResult>(context: context, barrierDismissible: false, builder: (BuildContext context) => DeleteAccountDialog(onDelete: onDelete));

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _secondStep = false;
  bool _matches = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() { _loading = true; _error = null; });
    try {
      final DeleteAccountResult result = await widget.onDelete();
      if (mounted) context.pop(result);
    } on SettingsPrivacyException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.status) {
          400 => context.l10n.settingsDeleteErrorConfirmation,
          401 => context.l10n.settingsDeleteErrorUnauthorized,
          _ => context.l10n.settingsDeleteErrorServer,
        };
      });
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.settingsDeleteErrorServer);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String word = l10n.settingsDeleteConfirmTypeWord;

    return AlertDialog(
      title: Text(l10n.settingsDeleteConfirmTitle),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(l10n.settingsDeleteConfirmBody),
          if (_secondStep) ...<Widget>[
            const SizedBox(height: 16),
            TextField(key: const Key('delete-confirmation-field'), controller: _controller, enabled: !_loading, autocorrect: false, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: l10n.settingsDeleteConfirmTypeLabel, hintText: word), onChanged: (String value) {
              final bool next = value.trim().toUpperCase() == word.toUpperCase();
              if (next != _matches) setState(() => _matches = next);
            }),
          ],
          if (_loading) ...<Widget>[const SizedBox(height: 16), const Center(child: CircularProgressIndicator())],
          if (_error != null) ...<Widget>[const SizedBox(height: 16), Text(_error!, style: TextStyle(color: context.m24.colors.danger))],
        ]),
      ),
      actions: <Widget>[
        TextButton(onPressed: _loading ? null : () => context.pop(), child: Text(l10n.commonCancel)),
        if (!_secondStep)
          FilledButton(key: const Key('delete-continue'), onPressed: () => setState(() => _secondStep = true), child: Text(l10n.commonContinue))
        else
          FilledButton(key: const Key('delete-confirm'), style: FilledButton.styleFrom(backgroundColor: context.m24.colors.danger), onPressed: _matches && !_loading ? _delete : null, child: Text(_error == null ? l10n.settingsDeleteConfirmAction : l10n.commonRetry)),
      ],
    );
  }
}
