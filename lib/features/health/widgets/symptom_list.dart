import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/features/health/data/symptom_models.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class SymptomList extends StatelessWidget {
  const SymptomList({super.key, required this.entries});
  final List<SymptomEntry> entries;

  @override
  Widget build(BuildContext context) {
    final Map<DateTime, List<SymptomEntry>> groups = <DateTime, List<SymptomEntry>>{};
    for (final SymptomEntry entry in entries) groups.putIfAbsent(DateUtils.dateOnly(entry.occurredAt), () => <SymptomEntry>[]).add(entry);
    return ListView(children: groups.entries.map((MapEntry<DateTime, List<SymptomEntry>> group) => Padding(padding: const EdgeInsets.only(bottom: 12), child: M24Card(padding: EdgeInsets.zero, child: Column(children: <Widget>[
      Padding(padding: const EdgeInsets.all(12), child: Row(children: <Widget>[M24DateTile(day: DateFormat.d().format(group.key), month: DateFormat.MMM(Localizations.localeOf(context).languageCode).format(group.key)), const SizedBox(width: 12), Expanded(child: Text(DateFormat.yMMMMd(Localizations.localeOf(context).languageCode).format(group.key), style: context.m24.text.h3))])),
      for (int index = 0; index < group.value.length; index++) ...<Widget>[if (index > 0) const Divider(), SymptomListRow(entry: group.value[index])],
    ])))).toList(growable: false));
  }
}

class SymptomListRow extends StatelessWidget {
  const SymptomListRow({super.key, required this.entry});
  final SymptomEntry entry;

  @override
  Widget build(BuildContext context) {
    final String name = entry.code == null ? entry.freeText ?? '' : context.l10n.t('symptom_${entry.code}');
    return M24ListRow(icon: M24Icons.symptoms, title: name, subtitle: '${context.l10n.t('symptomsSeverity')}: ${entry.severity}/5 · ${DateFormat.Hm(Localizations.localeOf(context).languageCode).format(entry.occurredAt)}', iconVariant: entry.severity >= 4 ? M24IconTileVariant.warning : M24IconTileVariant.primary, status: M24StatusPill(label: entry.editableAt(DateTime.now()) ? context.l10n.t('symptomsEditable') : context.l10n.t('symptomsRecorded'), variant: M24StatusPillVariant.neutral), onTap: () => context.push(AppRoutes.symptom(entry.id)));
  }
}