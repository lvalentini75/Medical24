import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/health/data/symptom_models.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/features/health/widgets/symptom_list.dart';
import 'package:medical24/features/health/widgets/health_navigation.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class SymptomsScreen extends ConsumerWidget {
  const SymptomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SymptomEntry>> state = ref.watch(symptomsProvider);
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    final Widget content = state.when(loading: () => const AppLoadingView(), error: (Object error, StackTrace _) => AppErrorView(message: AppFailure.from(error, where: 'symptoms').localized(Localizations.localeOf(context).languageCode), onRetry: () => ref.invalidate(symptomsProvider)), data: (List<SymptomEntry> entries) => entries.isEmpty ? M24EmptyState(icon: M24Icons.symptoms, title: context.l10n.t('symptomsEmptyTitle'), message: context.l10n.t('symptomsEmptyBody'), actionLabel: context.l10n.t('symptomsNew'), onAction: () => context.push(AppRoutes.symptomNew)) : RefreshIndicator(onRefresh: () => ref.refresh(symptomsProvider.future), child: SymptomList(entries: entries)));
    return SectionPage(title: context.l10n.t('symptomsTitle'), subtitle: context.l10n.t('symptomsSubtitle'), showDisclaimer: true, action: M24Button(label: context.l10n.t('symptomsNew'), icon: M24Icons.plus, onPressed: () => context.push(AppRoutes.symptomNew)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[HealthSectionNavigation(selected: HealthSection.symptoms, desktop: desktop), const SizedBox(height: 16), Expanded(child: content)]));
  }
}