import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/health/data/alert_models.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/features/health/widgets/alert_list.dart';
import 'package:medical24/features/health/widgets/health_navigation.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, HealthAlert alert) async {
    if (alert.isUnread) await ref.read(alertsRepositoryProvider).markRead(alert.id);
    ref.invalidate(alertsProvider);
    ref.invalidate(unreadAlertsProvider);
    if (context.mounted) context.push(AppRoutes.healthValue(alert.code));
  }

  Future<void> _markAll(WidgetRef ref) async {
    await ref.read(alertsRepositoryProvider).markAllRead();
    ref.invalidate(alertsProvider);
    ref.invalidate(unreadAlertsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<HealthAlert>> state = ref.watch(alertsProvider);
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    final Widget content = state.when(loading: () => const AppLoadingView(), error: (Object error, StackTrace _) => AppErrorView(message: AppFailure.from(error, where: 'alerts').localized(Localizations.localeOf(context).languageCode), onRetry: () => ref.invalidate(alertsProvider)), data: (List<HealthAlert> alerts) => alerts.isEmpty ? M24EmptyState(icon: M24Icons.alerts, title: context.l10n.t('alertsEmptyTitle'), message: context.l10n.t('alertsEmptyBody'), actionLabel: context.l10n.t('commonRetry'), onAction: () => ref.invalidate(alertsProvider)) : RefreshIndicator(onRefresh: () => ref.refresh(alertsProvider.future), child: HealthAlertList(alerts: alerts, onOpen: (HealthAlert alert) => _open(context, ref, alert))));
    return SectionPage(title: context.l10n.t('alertsTitle'), subtitle: context.l10n.t('alertsSubtitle'), showDisclaimer: true, action: M24Button(label: context.l10n.t('alertsMarkAllRead'), icon: M24Icons.confirm, onPressed: state.value?.any((HealthAlert alert) => alert.isUnread) == true ? () => _markAll(ref) : null, variant: M24ButtonVariant.secondary), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[HealthSectionNavigation(selected: HealthSection.alerts, desktop: desktop), const SizedBox(height: 16), Expanded(child: content)]));
  }
}