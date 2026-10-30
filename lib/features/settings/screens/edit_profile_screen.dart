import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_state_views.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final TextEditingController _name = TextEditingController();
  DateTime? _birthDate;
  String _gender = 'undisclosed';
  String _country = 'IT';
  bool _hydrated = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile profile) {
    if (_hydrated) return;
    _name.text = profile.fullName ?? '';
    _birthDate = profile.birthDate;
    _gender = profile.gender ?? 'undisclosed';
    _country = profile.country ?? 'IT';
    _hydrated = true;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final String language = Localizations.localeOf(context).languageCode;
    try {
      await ref.read(myProfileProvider.notifier).save(<String, dynamic>{
        'full_name': _name.text.trim(),
        'birth_date': _birthDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_birthDate!),
        'gender': _gender,
        'country': _country,
      });
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppFailure.from(e, where: 'editProfile')
                .localized(language))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String language = Localizations.localeOf(context).languageCode;
    final AsyncValue<UserProfile?> profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settingsEditProfile'))),
      body: profile.when(
        loading: () => const AppLoadingView(),
        error: (Object e, StackTrace _) => AppErrorView(
          message: AppFailure.from(e, where: 'editProfile').localized(language),
          onRetry: () => ref.read(myProfileProvider.notifier).refreshProfile(),
        ),
        data: (UserProfile? data) {
          if (data != null) _hydrate(data);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: AppSpacing.paddingLg,
                children: <Widget>[
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                        labelText: l10n.t('onboardingNameLabel')),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: () async {
                      final DateTime now = DateTime.now();
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _birthDate ?? DateTime(now.year - 35),
                        firstDate: DateTime(now.year - 120),
                        lastDate: now,
                      );
                      if (picked != null) setState(() => _birthDate = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                          labelText: l10n.t('onboardingBirthDateLabel')),
                      child: Text(_birthDate == null
                          ? l10n.t('onboardingBirthDatePick')
                          : DateFormat.yMMMMd(language).format(_birthDate!)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: InputDecoration(
                        labelText: l10n.t('onboardingGenderLabel')),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                          value: 'female',
                          child: Text(l10n.t('onboardingGenderFemale'))),
                      DropdownMenuItem<String>(
                          value: 'male',
                          child: Text(l10n.t('onboardingGenderMale'))),
                      DropdownMenuItem<String>(
                          value: 'other',
                          child: Text(l10n.t('onboardingGenderOther'))),
                      DropdownMenuItem<String>(
                          value: 'undisclosed',
                          child: Text(l10n.t('onboardingGenderUndisclosed'))),
                    ],
                    onChanged: (String? v) =>
                        setState(() => _gender = v ?? 'undisclosed'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _country,
                    decoration: InputDecoration(
                        labelText: l10n.t('onboardingCountryLabel')),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                          value: 'IT', child: Text('Italia')),
                      DropdownMenuItem<String>(
                          value: 'FR', child: Text('France')),
                      DropdownMenuItem<String>(
                          value: 'DE', child: Text('Deutschland')),
                      DropdownMenuItem<String>(
                          value: 'ES', child: Text('España')),
                      DropdownMenuItem<String>(
                          value: 'GB', child: Text('United Kingdom')),
                      DropdownMenuItem<String>(
                          value: 'OT', child: Text('Other / Altro')),
                    ],
                    onChanged: (String? v) =>
                        setState(() => _country = v ?? 'IT'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(l10n.t('commonSave')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
