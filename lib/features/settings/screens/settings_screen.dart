import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/core/models/user_profile.dart';
import 'package:medical24/core/providers/app_providers.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/security/app_lock_controller.dart';
import 'package:medical24/core/theme/app_theme.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/settings/data/settings_privacy_repository.dart';
import 'package:medical24/features/settings/data/settings_privacy_localizations.dart';
import 'package:medical24/features/settings/screens/export_data_screen.dart';
import 'package:medical24/features/settings/widgets/delete_account_dialog.dart';
import 'package:medical24/features/settings/widgets/settings_section.dart';
import 'package:medical24/features/family/providers/family_providers.dart';
import 'package:medical24/features/family/widgets/subject_selector.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const String appVersion = '1.0.0 (P00)';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _showExport = false;
  final SettingsPrivacyRepository _privacyRepository = const SupabaseSettingsPrivacyRepository();

  @override
  Widget build(BuildContext context) {
    if (_showExport) return ExportDataScreen(repository: _privacyRepository, onBack: () => setState(() => _showExport = false));
    final AppLocalizations l10n = context.l10n;
    final String language = Localizations.localeOf(context).languageCode;
    final AsyncValue<UserProfile?> profile = ref.watch(myProfileProvider);
    final AppLockState lock = ref.watch(appLockProvider);
    final AsyncValue<bool> caregiverMode = ref.watch(caregiverModeProvider);
    final String? currentSubjectId = ref.watch(currentSubjectProvider).value?.id;
    final String? userId = ref.watch(sessionProvider)?.user.id;
    final bool viewingSelf = currentSubjectId == null || currentSubjectId == userId;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settingsTitle'))),
      body: Column(children: <Widget>[
        const SubjectContextBanner(),
        Expanded(child: profile.when(
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
                if (viewingSelf) SettingsSection(
                  title: l10n.t('settingsProfileSection'),
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(M24Icons.profile),
                      title: Text(data?.fullName ?? l10n.t('settingsEditProfile')),
                      subtitle: Text(l10n.t('settingsEditProfile')),
                      trailing: const Icon(M24Icons.chevronRight),
                      onTap: () => context.push(AppRoutes.settingsProfile),
                    ),
                    ListTile(
                      leading: const Icon(M24Icons.users),
                      title: Text(l10n.familyTitle),
                      subtitle: Text(l10n.familySettingsBody),
                      trailing: const Icon(M24Icons.chevronRight),
                      onTap: () => context.push(AppRoutes.settingsFamily),
                    ),
                  ],
                ),
                if (viewingSelf) const SizedBox(height: AppSpacing.md),
                if (viewingSelf) SettingsSection(
                  title: l10n.t('accessibilityTitle'),
                  children: <Widget>[
                    SwitchListTile(
                      secondary: const Icon(M24Icons.users),
                      title: Text(l10n.t('accessibilityCaregiverMode')),
                      subtitle: Text(l10n.t('accessibilityCaregiverModeBody')),
                      value: caregiverMode.value ?? false,
                      onChanged: caregiverMode.isLoading ? null : ref.read(caregiverModeProvider.notifier).setEnabled,
                    ),
                  ],
                ),
                if (viewingSelf) const SizedBox(height: AppSpacing.md),
                if (viewingSelf) SettingsSection(
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
                if (viewingSelf) const SizedBox(height: AppSpacing.md),
                if (viewingSelf) SettingsSection(
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
                    if (viewingSelf) ListTile(
                      leading: const Icon(M24Icons.download),
                      title: Text(l10n.t('settingsExportData')),
                      subtitle: Text(l10n.t('settingsExportBody')),
                      trailing: const Icon(M24Icons.chevronRight),
                      onTap: () => setState(() => _showExport = true),
                    ),
                    if (viewingSelf) ListTile(
                      leading: Icon(M24Icons.delete, color: context.m24.colors.danger),
                      title: Text(l10n.t('settingsDeleteAccount'),
                          style: TextStyle(color: context.m24.colors.danger)),
                      subtitle: Text(l10n.t('settingsDeleteBody')),
                      onTap: () => _confirmDelete(context),
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
                      trailing: const Text(SettingsScreen.appVersion),
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
      )),
      ]),
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

  Future<void> _confirmDelete(BuildContext context) async {
    final AppLocalizations l10n = context.l10n;
    final AppLockState lock = ref.read(appLockProvider);
    if (lock.biometricsAvailable) {
      final bool ok = await ref
          .read(appLockProvider.notifier)
          .authenticate(l10n.t('settingsDeleteConfirmTitle'));
      if (!ok) return;
    }
    final DeleteAccountResult? result = await DeleteAccountDialog.show(context, onDelete: _privacyRepository.deleteAccount);
    if (result == null || !context.mounted) return;
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // The Edge Function already invalidated every server session.
    }
    if (context.mounted) {
      final String date = DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(result.purgeAt.toLocal());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsDeleteSuccess(date))));
      context.go(AppRoutes.welcome);
    }
  }
}
