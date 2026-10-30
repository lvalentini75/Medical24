import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/security/app_lock_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_state_views.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import '../widgets/settings_section.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';
import 'package:medical24/core/ui/tokens.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String appVersion = '1.0.0 (P00)';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String language = Localizations.localeOf(context).languageCode;
    final AsyncValue<UserProfile?> profile = ref.watch(myProfileProvider);
    final AppLockState lock = ref.watch(appLockProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settingsTitle'))),
      body: profile.when(
        loading: () => const AppLoadingView(),
        error: (Object e, StackTrace _) => AppErrorView(
          message: AppFailure.from(e, where: 'settings').localized(language),
          onRetry: () => ref.read(myProfileProvider.notifier).refreshProfile(),
        ),
        data: (UserProfile? data) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: AppSpacing.paddingLg,
              children: <Widget>[
                SettingsSection(
                  title: l10n.t('settingsProfileSection'),
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(M24Icons.profile),
                      title: Text(data?.fullName ?? l10n.t('settingsEditProfile')),
                      subtitle: Text(l10n.t('settingsEditProfile')),
                      trailing: const Icon(M24Icons.chevronRight),
                      onTap: () => context.push(AppRoutes.settingsProfile),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SettingsSection(
                  title: l10n.t('settingsPreferencesSection'),
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(M24Icons.language),
                      title: Text(l10n.t('settingsLanguage')),
                      trailing: DropdownButton<String>(
                        value: data?.language ?? language,
                        underline: const SizedBox.shrink(),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                              value: 'it', child: Text('Italiano')),
                          DropdownMenuItem<String>(
                              value: 'en', child: Text('English')),
                        ],
                        onChanged: (String? v) async {
                          if (v == null) return;
                          await ref
                              .read(myProfileProvider.notifier)
                              .save(<String, dynamic>{'language': v});
                          ref.read(localeProvider.notifier).setLocale(v);
                        },
                      ),
                    ),
                    ListTile(
                      leading: const Icon(M24Icons.ruler),
                      title: Text(l10n.t('settingsUnits')),
                      trailing: DropdownButton<String>(
                        value: data?.units ?? 'mg_dl',
                        underline: const SizedBox.shrink(),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                              value: 'mg_dl', child: Text('mg/dL')),
                          DropdownMenuItem<String>(
                              value: 'mmol_l', child: Text('mmol/L')),
                        ],
                        onChanged: (String? v) async {
                          if (v == null) return;
                          await ref
                              .read(myProfileProvider.notifier)
                              .save(<String, dynamic>{'units': v});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SettingsSection(
                  title: l10n.t('settingsSecuritySection'),
                  children: <Widget>[
                    SwitchListTile(
                      secondary: const Icon(M24Icons.fingerprint),
                      title: Text(l10n.t('settingsBiometricLock')),
                      subtitle: Text(lock.biometricsAvailable
                          ? l10n.t('settingsBiometricLockBody')
                          : l10n.t('settingsBiometricUnavailable')),
                      value: lock.enabled,
                      onChanged: (bool v) =>
                          ref.read(appLockProvider.notifier).setEnabled(v),
                    ),
                    ListTile(
                      leading: const Icon(M24Icons.pin),
                      title: Text(l10n.t('settingsPinFallback')),
                      subtitle: Text(lock.hasPin
                          ? l10n.t('settingsPinSaved')
                          : l10n.t('settingsPinSet')),
                      trailing: const Icon(M24Icons.chevronRight),
                      onTap: () => _showPinDialog(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SettingsSection(
                  title: l10n.t('settingsPrivacySection'),
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(M24Icons.consent),
                      title: Text(l10n.t('settingsConsents')),
                      trailing: const Icon(M24Icons.chevronRight),
                      onTap: () => context.push(AppRoutes.settingsConsents),
                    ),
                    ListTile(
                      leading: const Icon(M24Icons.download),
                      title: Text(l10n.t('settingsExportData')),
                      subtitle: Text(l10n.t('settingsExportBody')),
                      onTap: () => _exportData(context, ref),
                    ),
                    ListTile(
                      leading: Icon(M24Icons.delete, color: context.m24.colors.danger),
                      title: Text(l10n.t('settingsDeleteAccount'),
                          style: TextStyle(color: context.m24.colors.danger)),
                      subtitle: Text(l10n.t('settingsDeleteBody')),
                      onTap: () => _confirmDelete(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SettingsSection(
                  title: l10n.t('settingsAboutSection'),
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(M24Icons.info),
                      title: Text(l10n.t('settingsAppVersion')),
                      trailing: Text(appVersion),
                    ),
                    ListTile(
                      leading: const Icon(M24Icons.logout),
                      title: Text(l10n.t('authSignOut')),
                      onTap: () async {
                        await ref.read(authRepositoryProvider).signOut();
                        if (context.mounted) context.go(AppRoutes.welcome);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const ClinicalDisclaimer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPinDialog(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController();
    final AppLocalizations l10n = context.l10n;
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.t('settingsPinSet')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly
          ],
          decoration: InputDecoration(
              labelText: l10n.t('settingsPinLabel'), counterText: ''),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => ctx.pop(false),
              child: Text(l10n.t('commonCancel'))),
          FilledButton(
              onPressed: () => ctx.pop(true),
              child: Text(l10n.t('commonSave'))),
        ],
      ),
    );
    if (saved == true && controller.text.length == 6) {
      await ref.read(appLockProvider.notifier).setPin(controller.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('settingsPinSaved'))));
      }
    }
    controller.dispose();
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    try {
      final repo = ref.read(profileRepositoryProvider);
      final UserProfile? profile = await repo.fetchMyProfile();
      final List<Map<String, dynamic>> consents = (await repo.fetchMyConsents())
          .map((c) => c.toJson())
          .toList();
      final List<Map<String, dynamic>> audit = await repo.fetchMyAuditLog();
      final String payload = const JsonEncoder.withIndent('  ')
          .convert(<String, dynamic>{
        'profile': profile?.toJson(),
        'consents': consents,
        'audit_log': audit,
      });
      await Clipboard.setData(ClipboardData(text: payload));
      await repo.logAudit('data_exported', targetTable: 'profiles');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('settingsExportDone'))));
      }
    } catch (e) {
      final String language = Localizations.localeOf(context).languageCode;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                AppFailure.from(e, where: 'settings.export').localized(language))));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.t('settingsDeleteConfirmTitle')),
        content: Text(l10n.t('settingsDeleteConfirmBody')),
        actions: <Widget>[
          TextButton(
              onPressed: () => ctx.pop(false),
              child: Text(l10n.t('commonCancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusRed),
            onPressed: () => ctx.pop(true),
            child: Text(l10n.t('settingsDeleteConfirmAction')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final AppLockState lock = ref.read(appLockProvider);
    if (lock.biometricsAvailable) {
      final bool ok = await ref
          .read(appLockProvider.notifier)
          .authenticate(l10n.t('settingsDeleteConfirmTitle'));
      if (!ok) return;
    }

    try {
      await ref.read(profileRepositoryProvider).deleteAccount();
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) context.go(AppRoutes.welcome);
    } catch (e) {
      final String language = Localizations.localeOf(context).languageCode;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppFailure.from(e, where: 'settings.delete')
                .localized(language))));
      }
    }
  }
}
