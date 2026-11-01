import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/social_auth_buttons.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/widgets/controls.dart';

/// Sign in and sign up share the same form; [isSignUp] switches the mode.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.isSignUp = false});

  final bool isSignUp;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  bool _devShortcuts = false;
  bool _adminShortcut = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isSignUp) _loadDevShortcuts();
  }

  Future<void> _loadDevShortcuts() async {
    final bool enabled = await ref.read(authRepositoryProvider).devShortcutsEnabled();
    if (mounted) setState(() => _devShortcuts = enabled);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
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
            _error = AppFailure.from(e, where: 'signIn').localized(_languageCode));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(authRepositoryProvider);
    await _run(() async {
      if (widget.isSignUp) {
        await repo.signUpWithEmail(
            email: _email.text, password: _password.text);
      } else {
        await repo.signInWithEmail(
            email: _email.text, password: _password.text);
        if (_adminShortcut && mounted) context.go(AppRoutes.admin);
      }
    });
  }

  void _applyShortcut(String email, {bool admin = false}) {
    _email.text = email;
    _adminShortcut = admin;
    _passwordFocus.requestFocus();
    setState(() {});
  }

  Future<void> _otp() async {
    final String email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = context.l10n.t('authEmailInvalid'));
      return;
    }
    await _run(() async {
      await ref.read(authRepositoryProvider).sendEmailOtp(email);
      if (mounted) {
        context.push('${AppRoutes.otp}?email=${Uri.encodeComponent(email)}');
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
        onPressed: () => context.go(AppRoutes.welcome),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.t(widget.isSignUp ? 'authSignUpTitle' : 'authSignInTitle'),
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_error != null) ...<Widget>[
              AuthErrorBanner(message: _error!),
              const SizedBox(height: AppSpacing.md),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.email],
              decoration: InputDecoration(labelText: l10n.t('authEmailLabel')),
              validator: (String? v) {
                final String value = (v ?? '').trim();
                if (value.isEmpty || !value.contains('@') || !value.contains('.')) {
                  return l10n.t('authEmailInvalid');
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _password,
              focusNode: _passwordFocus,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: l10n.t('authPasswordLabel'),
                helperText: widget.isSignUp ? l10n.t('authPasswordHint') : null,
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? M24Icons.eye : M24Icons.eyeOff),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (String? v) {
                if ((v ?? '').length < 8) return l10n.t('authPasswordShort');
                return null;
              },
            ),
            if (!widget.isSignUp)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(AppRoutes.resetPassword),
                  child: Text(l10n.t('authForgotPassword')),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            M24Button(label: l10n.t(widget.isSignUp ? 'authSignUpAction' : 'authSignInAction'), size: M24ButtonSize.large, loading: _busy, onPressed: _busy ? null : _submit),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _busy ? null : _otp,
              child: Text(l10n.t('authOtpAction')),
            ),
            const SizedBox(height: AppSpacing.md),
            SocialAuthButtons(
              busy: _busy,
              onApple: () =>
                  _run(() => ref.read(authRepositoryProvider).signInWithApple()),
              onGoogle: () =>
                  _run(() => ref.read(authRepositoryProvider).signInWithGoogle()),
            ),
            if (_devShortcuts) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.t('authDevShortcutsTitle'), style: theme.textTheme.bodySmall),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                children: <Widget>[
                  M24FilterChip(label: l10n.t('authDevShortcutAdmin'), selected: false, onSelected: (_) => _applyShortcut('admin@medical24.app', admin: true)),
                  M24FilterChip(label: l10n.t('authDevShortcutAlice'), selected: false, onSelected: (_) => _applyShortcut('alice.test@medical24.app')),
                  M24FilterChip(label: l10n.t('authDevShortcutBob'), selected: false, onSelected: (_) => _applyShortcut('bob.test@medical24.app')),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    l10n.t(widget.isSignUp ? 'authHasAccount' : 'authNoAccount'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(
                      widget.isSignUp ? AppRoutes.signIn : AppRoutes.signUp),
                  child: Text(l10n.t(
                      widget.isSignUp ? 'authSignInAction' : 'authSignUpAction')),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.t('authPrivacyNote'),
                style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
