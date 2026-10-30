import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import '../widgets/auth_scaffold.dart';
import 'package:medical24/core/ui/icons.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final TextEditingController _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = context.l10n.t('authEmailInvalid'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordRecoveryOtp(email);
      if (mounted) {
        context.push(
            '${AppRoutes.otp}?email=${Uri.encodeComponent(email)}&recovery=1');
      }
    } catch (e) {
      final String code = Localizations.localeOf(context).languageCode;
      if (mounted) {
        setState(() => _error =
            AppFailure.from(e, where: 'resetPassword').localized(code));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AuthScaffold(
      leading: IconButton(
        icon: const Icon(M24Icons.back),
        onPressed: () => context.pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l10n.t('authResetTitle'),
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.t('authResetSubtitle'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null) ...<Widget>[
            AuthErrorBanner(message: _error!),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.t('authEmailLabel')),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _send,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(l10n.t('authResetAction')),
          ),
        ],
      ),
    );
  }
}
