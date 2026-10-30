import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/widgets/controls.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

enum HealthSection { body, biomarkers, prevention, symptoms, alerts }

  /// Adaptive navigation for the body overview and health journals.
class HealthSectionNavigation extends StatelessWidget {
  const HealthSectionNavigation({super.key, required this.selected, this.desktop = false});
  final HealthSection selected;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    void open(HealthSection section) => context.go(switch (section) { HealthSection.body => AppRoutes.health, HealthSection.biomarkers => AppRoutes.healthValues, HealthSection.prevention => AppRoutes.prevention, HealthSection.symptoms => AppRoutes.symptoms, HealthSection.alerts => AppRoutes.alerts });
    if (desktop) return M24Tabs(labels: <String>[context.l10n.bodyTitle, context.l10n.t('healthTabAllValues'), context.l10n.preventionNav, context.l10n.t('healthTabHistory'), context.l10n.t('symptomsTitle'), context.l10n.t('alertsTitle')], index: switch (selected) { HealthSection.body => 0, HealthSection.biomarkers => 1, HealthSection.prevention => 2, HealthSection.symptoms => 4, HealthSection.alerts => 5 }, onChanged: (int index) { if (index == 0) open(HealthSection.body); if (index == 1 || index == 3) open(HealthSection.biomarkers); if (index == 2) open(HealthSection.prevention); if (index == 4) open(HealthSection.symptoms); if (index == 5) open(HealthSection.alerts); });
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: M24Segmented<HealthSection>(segments: <M24Segment<HealthSection>>[
      M24Segment<HealthSection>(value: HealthSection.body, label: context.l10n.bodySegment, icon: M24Icons.profile),
      M24Segment<HealthSection>(value: HealthSection.biomarkers, label: context.l10n.t('healthSegmentValues'), icon: M24Icons.chart),
      M24Segment<HealthSection>(value: HealthSection.prevention, label: context.l10n.preventionNav, icon: M24Icons.prevention),
      M24Segment<HealthSection>(value: HealthSection.symptoms, label: context.l10n.t('healthSegmentSymptoms'), icon: M24Icons.symptoms),
      M24Segment<HealthSection>(value: HealthSection.alerts, label: context.l10n.t('healthSegmentAlerts'), icon: M24Icons.alerts),
    ], selected: selected, onChanged: open));
  }
}