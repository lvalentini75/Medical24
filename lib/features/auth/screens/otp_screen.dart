import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import '../widgets/auth_scaffold.dart';
import 'package:medical24/core/ui/icons.dart';

/// Verifies the 6-digit email OTP. Used both for passwordless sign-in
/// and for password recovery (`isRecovery`).
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.email, this.isRecovery = false});

  final String email;
  final bool isRecovery;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  String get _languageCode => Localizations.localeOf(context).languageCode;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.localized(_languageCode));
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = AppFailure.from(e, where: 'otp').localized(_languageCode));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().length < 6) return;
    if (widget.isRecovery && _newPassword.text.length < 8) {
      setState(() => _error = context.l10n.t('authPasswordShort'));
      return;
    }
    await _run(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.verifyEmailOtp(
        email: widget.email,
        token: _code.text,
        type: widget.isRecovery ? OtpType.recovery : OtpType.email,
      );
      if (widget.isRecovery) {
        await repo.updatePassword(_newPassword.text);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n
              .t(widget.isRecovery ? 'authResetDone' : 'authOtpSent')),
        ));
      }
    });
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
          Text(l10n.t('authOtpTitle'),
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.t('authOtpSubtitle', args: <String, String>{'email': widget.email}),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null) ...<Widget>[
            AuthErrorBanner(message: _error!),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly
            ],
            decoration: InputDecoration(
                labelText: l10n.t('authOtpLabel'), counterText: ''),
          ),
          if (widget.isRecovery) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _newPassword,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.t('authNewPasswordLabel'),
                helperText: l10n.t('authPasswordHint'),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _verify,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(l10n.t('authOtpVerify')),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                      final repo = ref.read(authRepositoryProvider);
                      if (widget.isRecovery) {
                        await repo.sendPasswordRecoveryOtp(widget.email);
                      } else {
                        await repo.sendEmailOtp(widget.email);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(context.l10n.t('authOtpSent'))));
                      }
                    }),
            child: Text(l10n.t('authOtpResend')),
          ),
        ],
      ),
    );
  }
}
