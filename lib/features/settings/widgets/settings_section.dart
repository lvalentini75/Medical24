import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Titled group of settings rows inside a Calm Health card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}
