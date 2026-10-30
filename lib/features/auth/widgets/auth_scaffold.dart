import 'package:flutter/material.dart';

import 'package:medical24/core/ui/widgets/branding.dart';
import 'package:medical24/core/ui/widgets/feedback.dart';

/// Shared layout for the authentication screens.
/// Phone: full width with padding. Desktop: centred 480 px column.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child, this.leading});

  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: leading == null ? null : AppBar(leading: leading),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[const Center(child: M24Logo(height: 40)), const SizedBox(height: 32), child]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline, neutral error message used across the auth forms.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return M24Banner(title: message, subtitle: '', variant: M24BannerVariant.warning);
    /* return Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 18, color: AppColors.statusRed),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.statusRed),
              softWrap: true,
            ),
          ),
        ],
      ),
    ); */
  }
}
