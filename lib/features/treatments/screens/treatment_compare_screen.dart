import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/treatments/data/treatment_models.dart';
import 'package:medical24/features/treatments/providers/treatments_providers.dart';
import 'package:medical24/features/treatments/widgets/treatment_widgets.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class TreatmentCompareScreen extends ConsumerWidget {
  const TreatmentCompareScreen({super.key, required this.ids});
  final List<String> ids;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ids.length < 2 || ids.length > 4) return AppEmptyView(title: context.l10n.t('treatmentsCompareTitle'), body: context.l10n.t('treatmentsCompareNeedTwo'));
    return SectionPage(title: context.l10n.t('treatmentsCompareTitle'), showDisclaimer: true, action: M24Button(label: context.l10n.t('treatmentsClearCompare'), variant: M24ButtonVariant.outline, onPressed: () => ref.read(treatmentCompareSelectionProvider.notifier).clear()), child: ref.watch(treatmentCompareProvider(ids)).when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: context.l10n.t('treatmentsLoadError')), data: (items) => TreatmentComparisonTable(items: items)));
  }
}
class TreatmentComparisonTable extends StatelessWidget {
  const TreatmentComparisonTable({super.key, required this.items});
  final List<CompareTreatment> items;
  @override
  Widget build(BuildContext context) {
    final List<(String, String)> rows = <(String, String)>[('session_minutes','treatmentsDuration'),('sessions_count','treatmentsSessions'),('course_weeks','treatmentsWeeks'),('price_from_cents','treatmentsCost'),('waiting_days','treatmentsWaiting'),('modality','treatmentsModality'),('evidence_level','treatmentsEvidence'),('max_contraindication_severity','treatmentsContraindications'),('rating_avg','treatmentsRatings'),('doctor_display_name','treatmentsProfessional'),('facility_name','treatmentsFacility')];
    String value(CompareTreatment item, String key) { final dynamic raw = item.data[key]; if (raw == null) return '-'; if (key == 'price_from_cents') return treatmentPrice(context, (raw as num).toInt()); if (<String>['modality','evidence_level','max_contraindication_severity'].contains(key)) return treatmentLabel(context, raw.toString()); return raw.toString(); }
    final double width = 220.0 * items.length;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[SizedBox(width: 150, child: Column(children: <Widget>[const SizedBox(height: 72), for (final row in rows) Container(height: 56, alignment: Alignment.centerLeft, padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.m24.colors.divider))), child: Text(context.l10n.t(row.$2), style: context.m24.text.label))])), Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: width, child: Row(children: <Widget>[for (final item in items) SizedBox(width: 220, child: Column(children: <Widget>[Container(height: 72, padding: const EdgeInsets.all(8), alignment: Alignment.center, color: context.m24.colors.surfaceAlt, child: Text(item.title, textAlign: TextAlign.center, style: context.m24.text.title)), for (final row in rows) Container(height: 56, alignment: Alignment.center, padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.m24.colors.divider))), child: Text(value(item, row.$1), textAlign: TextAlign.center))]))]))))]);
  }
}