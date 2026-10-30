import 'package:flutter/material.dart';

import 'package:medical24/l10n/generated/localization_lookup.dart';
import '../ui/widgets/feedback.dart';
import '../ui/widgets/headers.dart';
import '../theme/app_theme.dart';

/// Loading state for any data-backed screen.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
              width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.4)),
          const SizedBox(height: AppSpacing.md),
          Text(
            message ?? context.l10n.t('commonLoading'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Readable error state with a retry action. Never shows clinical content.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, color: AppColors.statusRed, size: 32),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.t('commonErrorTitle'),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message,
                style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(context.l10n.t('commonRetry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state with a suggestion of what to do next.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.body,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String body;
  final String? title;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 34, color: AppColors.neutralGrey),
              const SizedBox(height: AppSpacing.md),
              Text(
                title ?? context.l10n.t('commonEmptyTitle'),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(body,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center),
              if (action != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "This is not a diagnosis" banner, mandatory on every clinical screen.
class ClinicalDisclaimer extends StatelessWidget {
  const ClinicalDisclaimer({super.key});

  @override
  Widget build(BuildContext context) => M24Disclaimer(phoneText: context.l10n.t('disclaimerPhone'), desktopText: context.l10n.t('disclaimerDesktop'));
}

/// Page scaffold shared by the five sections: title, optional action,
/// content capped and padded consistently across breakpoints.
class SectionPage extends StatelessWidget {
  const SectionPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    this.showDisclaimer = false,
    this.constrainWidth = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  final bool showDisclaimer;
  final bool constrainWidth;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final double gutter = width >= 1200 ? 32 : width >= 600 ? 24 : 16;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          M24PageHeader(title: title, subtitle: subtitle, action: action),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: constrainWidth ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1440), child: child)) : child),
          if (showDisclaimer) ...<Widget>[const SizedBox(height: AppSpacing.md), const ClinicalDisclaimer()],
        ],
      ),
    );
  }
}
