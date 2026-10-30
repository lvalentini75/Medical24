import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import '../widgets/auth_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 24),
          Text(
            l10n.t('authWelcomeTitle'),
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(l10n.t('authWelcomeSubtitle'),
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 32),
          M24Button(label: l10n.t('authWelcomeSignUp'), size: M24ButtonSize.large, onPressed: () => context.go(AppRoutes.signUp)),
          const SizedBox(height: 12),
          M24Button(label: l10n.t('authWelcomeSignIn'), variant: M24ButtonVariant.outline, size: M24ButtonSize.large, onPressed: () => context.go(AppRoutes.signIn)),
          const SizedBox(height: 24),
          Text(
            l10n.t('authPrivacyNote'),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
