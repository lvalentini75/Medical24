import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medical24/l10n/generated/localization_lookup.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'app_lock_controller.dart';

/// Wraps the whole app: when the lock is on and the app is not unlocked,
/// the content is replaced by the unlock screen.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(appLockProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLockState lock = ref.watch(appLockProvider);
    if (!lock.shouldBlock) return widget.child;
    return const _LockScreen();
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  final TextEditingController _pin = TextEditingController();
  bool _showPin = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppLockState lock = ref.watch(appLockProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Icon(Icons.lock_outline,
                      size: 40, color: AppColors.accent),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.t('lockTitle'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.t('lockSubtitle'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xl),
                  if (_showPin || !lock.biometricsAvailable) ...<Widget>[
                    TextField(
                      controller: _pin,
                      obscureText: true,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.t('settingsPinLabel'),
                        counterText: '',
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () async {
                        final bool ok = await ref
                            .read(appLockProvider.notifier)
                            .verifyPin(_pin.text);
                        if (!ok && mounted) {
                          setState(() => _error = l10n.t('lockPinWrong'));
                        }
                      },
                      child: Text(l10n.t('lockUnlock')),
                    ),
                  ] else ...<Widget>[
                    FilledButton.icon(
                      icon: const Icon(Icons.fingerprint),
                      onPressed: () => ref
                          .read(appLockProvider.notifier)
                          .authenticate(l10n.t('lockSubtitle')),
                      label: Text(l10n.t('lockUnlock')),
                    ),
                    if (lock.hasPin)
                      TextButton(
                        onPressed: () => setState(() => _showPin = true),
                        child: Text(l10n.t('lockUsePin')),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
