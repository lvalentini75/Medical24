import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/consent_record.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_state_views.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

final FutureProvider<List<ConsentRecord>> myConsentsProvider =
    FutureProvider<List<ConsentRecord>>((Ref ref) async {
  return ref.read(profileRepositoryProvider).fetchMyConsents();
});

/// Append-only consent register: every grant and revoke, with its version.
class ConsentsLogScreen extends ConsumerWidget {
  const ConsentsLogScreen({super.key});

  String _label(AppLocalizations l10n, ConsentType type) {
    switch (type) {
      case ConsentType.healthData:
        return l10n.t('onboardingConsentHealth');
      case ConsentType.aiProcessing:
        return l10n.t('onboardingConsentAi');
      case ConsentType.marketing:
        return l10n.t('onboardingConsentMarketing');
      default:
        return type.value;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String language = Localizations.localeOf(context).languageCode;
    final AsyncValue<List<ConsentRecord>> consents =
        ref.watch(myConsentsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('consentsLogTitle'))),
      body: consents.when(
        loading: () => const AppLoadingView(),
        error: (Object e, StackTrace _) => AppErrorView(
          message: AppFailure.from(e, where: 'consentsLog').localized(language),
          onRetry: () => ref.invalidate(myConsentsProvider),
        ),
        data: (List<ConsentRecord> items) {
          if (items.isEmpty) {
            return AppEmptyView(
              icon: Icons.fact_check_outlined,
              body: l10n.t('consentsLogEmpty'),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.separated(
                padding: AppSpacing.paddingLg,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (BuildContext context, int i) {
                  final ConsentRecord c = items[i];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        c.granted ? Icons.check_circle : Icons.cancel,
                        color: c.granted
                            ? AppColors.statusGreen
                            : AppColors.neutralGrey,
                      ),
                      title: Text(_label(l10n, c.type)),
                      subtitle: Text(
                        '${l10n.t(c.granted ? 'consentGranted' : 'consentRevoked')} · v${c.version} · '
                        '${DateFormat.yMMMd(language).add_Hm().format(c.grantedAt.toLocal())}',
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
