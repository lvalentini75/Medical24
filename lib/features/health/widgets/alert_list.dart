import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/features/health/data/alert_models.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class HealthAlertList extends StatelessWidget {
  const HealthAlertList({super.key, required this.alerts, required this.onOpen});
  final List<HealthAlert> alerts;
  final ValueChanged<HealthAlert> onOpen;

  @override
  Widget build(BuildContext context) => ListView.separated(itemCount: alerts.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (BuildContext context, int index) => HealthAlertRow(alert: alerts[index], onOpen: () => onOpen(alerts[index])));
}

class HealthAlertRow extends StatelessWidget {
  const HealthAlertRow({super.key, required this.alert, required this.onOpen});
  final HealthAlert alert;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final String language = Localizations.localeOf(context).languageCode;
    final M24IconTileVariant tile = switch (alert.type) { HealthAlertType.critical => M24IconTileVariant.danger, HealthAlertType.warning => M24IconTileVariant.warning, HealthAlertType.info => M24IconTileVariant.info };
    final M24StatusPillVariant pill = switch (alert.type) { HealthAlertType.critical => M24StatusPillVariant.danger, HealthAlertType.warning => M24StatusPillVariant.warning, HealthAlertType.info => M24StatusPillVariant.info };
    final IconData icon = switch (alert.type) { HealthAlertType.critical => LucideIcons.circleAlert, HealthAlertType.warning => LucideIcons.triangleAlert, HealthAlertType.info => M24Icons.info };
    return M24Card(tint: alert.isUnread && alert.type == HealthAlertType.warning ? M24CardTint.warning : M24CardTint.none, padding: EdgeInsets.zero, child: Column(children: <Widget>[
      M24ListRow(icon: icon, iconVariant: tile, title: alert.name(language), subtitle: '${context.l10n.t('alertsLevel_${alert.level}')} · ${DateFormat.yMd(language).add_Hm().format(alert.createdAt)}', status: M24StatusPill(label: context.l10n.t(alert.isUnread ? 'alertsUnread' : 'alertsRead'), variant: alert.isUnread ? pill : M24StatusPillVariant.neutral), onTap: onOpen),
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: Align(alignment: Alignment.centerLeft, child: Text(context.l10n.t(alert.messageKey), style: context.m24.text.bodySmall))),
      if (alert.type == HealthAlertType.critical) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Align(alignment: Alignment.centerLeft, child: M24Button(label: context.l10n.t('alertsContactDoctor'), icon: LucideIcons.stethoscope, onPressed: () => context.go(AppRoutes.doctor), variant: M24ButtonVariant.warning, size: M24ButtonSize.small))),
    ]));
  }
}