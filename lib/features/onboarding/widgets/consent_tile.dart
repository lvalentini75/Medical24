import 'package:flutter/material.dart';
import 'package:medical24/core/theme/app_theme.dart';

import 'package:medical24/core/ui/widgets/surfaces.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// One consent, with its versioned text and an explicit switch.
/// Consents are never bundled: one switch each.
class ConsentTile extends StatelessWidget {
  const ConsentTile({
    super.key,
    required this.title,
    required this.body,
    required this.version,
    required this.value,
    required this.onChanged,
    this.required = false,
  });

  final String title;
  final String body;
  final String version;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return M24Card(
      child: Padding(
            padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (required)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            context.l10n.t('onboardingConsentRequired'),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: context.m24.colors.primary),
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: theme.textTheme.bodySmall, softWrap: true),
            const SizedBox(height: AppSpacing.sm),
            Text('v$version', style: theme.textTheme.labelSmall?.copyWith(color: context.m24.colors.inkMuted)),
          ],
        ),
      ),
    );
  }
}
