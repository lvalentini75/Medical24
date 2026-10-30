import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Apple and Google sign-in buttons. Apple is hidden where it is not offered.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.onApple,
    required this.onGoogle,
    this.busy = false,
  });

  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final bool busy;

  bool get _showApple =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(l10n.t('authOrDivider'),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_showApple) ...<Widget>[
          OutlinedButton.icon(
            onPressed: busy ? null : onApple,
            icon: const Icon(Icons.apple, color: Colors.black87),
            label: Text(l10n.t('authAppleAction')),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        OutlinedButton.icon(
          onPressed: busy ? null : onGoogle,
          icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.blue),
          label: Text(l10n.t('authGoogleAction')),
        ),
      ],
    );
  }
}
