import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/consent_record.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import 'package:medical24/core/ui/widgets/branding.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/feedback.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import '../widgets/consent_tile.dart';

/// Three steps: consents → basic data → "profile ready".
/// Every consent writes an append-only row in `consents` through
/// the `record_consent` function.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _totalSteps = 3;

  int _step = 0;
  bool _busy = false;
  String? _error;

  bool _consentHealth = false;
  bool _consentAi = false;
  bool _consentMarketing = false;

  final TextEditingController _name = TextEditingController();
  DateTime? _birthDate;
  String _gender = 'undisclosed';
  String _language = 'it';
  String _units = 'mg_dl';
  String _country = 'IT';

  @override
  void initState() {
    super.initState();
    _language = WidgetsBinding.instance.platformDispatcher.locale.languageCode
                .startsWith('en')
        ? 'en'
        : 'it';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _languageCode => Localizations.localeOf(context).languageCode;

  Future<void> _submitConsents() async {
    if (!_consentHealth) {
      setState(() => _error = context.l10n.t('onboardingConsentMissing'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.recordConsent(
        type: ConsentType.healthData,
        version: ConsentVersions.healthData,
        granted: true,
        locale: _language,
      );
      await repo.recordConsent(
        type: ConsentType.aiProcessing,
        version: ConsentVersions.aiProcessing,
        granted: _consentAi,
        locale: _language,
      );
      await repo.recordConsent(
        type: ConsentType.marketing,
        version: ConsentVersions.marketing,
        granted: _consentMarketing,
        locale: _language,
      );
      if (mounted) setState(() => _step = 1);
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppFailure.from(e, where: 'onboarding.consents')
            .localized(_languageCode));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitBasics() async {
    if (_name.text.trim().isEmpty || _birthDate == null) {
      setState(() => _error = context.l10n.t('commonRequired'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(myProfileProvider.notifier)
          .completeOnboarding(<String, dynamic>{
        'full_name': _name.text.trim(),
        'birth_date': DateFormat('yyyy-MM-dd').format(_birthDate!),
        'gender': _gender,
        'language': _language,
        'units': _units,
        'country': _country,
      });
      ref.read(localeProvider.notifier).setLocale(_language);
      if (mounted) setState(() => _step = 2);
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppFailure.from(e, where: 'onboarding.basics')
            .localized(_languageCode));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Center(child: M24Logo(height: 40)),
                  const SizedBox(height: 24),
                  Text(
                    l10n.t('onboardingStepLabel', args: <String, String>{
                      'current': '${_step + 1}',
                      'total': '$_totalSteps',
                    }),
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LinearProgressIndicator(
                    value: (_step + 1) / _totalSteps,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_error != null) ...<Widget>[
                    M24Banner(title: _error!, subtitle: '', variant: M24BannerVariant.warning),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_step == 0) _buildConsents(context),
                  if (_step == 1) _buildBasics(context),
                  if (_step == 2) _buildReady(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConsents(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.t('onboardingConsentTitle'),
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.t('onboardingConsentSubtitle'),
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        ConsentTile(
          title: l10n.t('onboardingConsentHealth'),
          body: l10n.t('onboardingConsentHealthBody'),
          version: ConsentVersions.healthData,
          required: true,
          value: _consentHealth,
          onChanged: (bool v) => setState(() => _consentHealth = v),
        ),
        const SizedBox(height: AppSpacing.md),
        ConsentTile(
          title: l10n.t('onboardingConsentAi'),
          body: l10n.t('onboardingConsentAiBody'),
          version: ConsentVersions.aiProcessing,
          value: _consentAi,
          onChanged: (bool v) => setState(() => _consentAi = v),
        ),
        const SizedBox(height: AppSpacing.md),
        ConsentTile(
          title: l10n.t('onboardingConsentMarketing'),
          body: l10n.t('onboardingConsentMarketingBody'),
          version: ConsentVersions.marketing,
          value: _consentMarketing,
          onChanged: (bool v) => setState(() => _consentMarketing = v),
        ),
        const SizedBox(height: AppSpacing.xl),
        M24Button(label: l10n.t('commonContinue'), size: M24ButtonSize.large, loading: _busy, onPressed: _busy ? null : _submitConsents),
      ],
    );
  }

  Widget _buildBasics(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.t('onboardingBasicsTitle'),
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.t('onboardingBasicsSubtitle'),
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.t('onboardingNameLabel')),
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
            child: Text(
              _birthDate == null
                  ? l10n.t('onboardingBirthDatePick')
                  : DateFormat.yMMMMd(_language).format(_birthDate!),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          decoration:
              InputDecoration(labelText: l10n.t('onboardingGenderLabel')),
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(
                value: 'female', child: Text(l10n.t('onboardingGenderFemale'))),
            DropdownMenuItem<String>(
                value: 'male', child: Text(l10n.t('onboardingGenderMale'))),
            DropdownMenuItem<String>(
                value: 'other', child: Text(l10n.t('onboardingGenderOther'))),
            DropdownMenuItem<String>(
                value: 'undisclosed',
                child: Text(l10n.t('onboardingGenderUndisclosed'))),
          ],
          onChanged: (String? v) =>
              setState(() => _gender = v ?? 'undisclosed'),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _language,
          decoration:
              InputDecoration(labelText: l10n.t('onboardingLanguageLabel')),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: 'it', child: Text('Italiano')),
            DropdownMenuItem<String>(value: 'en', child: Text('English')),
          ],
          onChanged: (String? v) => setState(() => _language = v ?? 'it'),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _units,
          decoration:
              InputDecoration(labelText: l10n.t('onboardingUnitsLabel')),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: 'mg_dl', child: Text('mg/dL')),
            DropdownMenuItem<String>(value: 'mmol_l', child: Text('mmol/L')),
          ],
          onChanged: (String? v) => setState(() => _units = v ?? 'mg_dl'),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _country,
          decoration:
              InputDecoration(labelText: l10n.t('onboardingCountryLabel')),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: 'IT', child: Text('Italia')),
            DropdownMenuItem<String>(value: 'FR', child: Text('France')),
            DropdownMenuItem<String>(value: 'DE', child: Text('Deutschland')),
            DropdownMenuItem<String>(value: 'ES', child: Text('España')),
            DropdownMenuItem<String>(
                value: 'GB', child: Text('United Kingdom')),
            DropdownMenuItem<String>(value: 'OT', child: Text('Other / Altro')),
          ],
          onChanged: (String? v) => setState(() => _country = v ?? 'IT'),
        ),
        const SizedBox(height: AppSpacing.xl),
        M24Button(label: l10n.t('commonContinue'), size: M24ButtonSize.large, loading: _busy, onPressed: _busy ? null : _submitBasics),
      ],
    );
  }

  Widget _buildReady(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Icon(Icons.check_circle_outline,
            size: 48, color: AppColors.statusGreen),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.t('onboardingReadyTitle'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.t('onboardingReadySubtitle'),
            textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        M24Button(label: l10n.t('onboardingReadyAction'), size: M24ButtonSize.large, onPressed: () => context.go(AppRoutes.home)),
      ],
    );
  }
}
