import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/features/health/prevention/data/prevention_models.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class PreventionRecommendationRow extends StatelessWidget {
  const PreventionRecommendationRow({super.key, required this.item, required this.onComplete, required this.onDismiss});
  final PreventionRecommendation item;
  final VoidCallback onComplete;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();
    final bool future = item.dueAt != null && item.dueAt!.isAfter(today);
    final bool visitWithoutInterval = item.category.toLowerCase().contains('visit') && (item.intervalMonths ?? 0) == 0;
    final String state = visitWithoutInterval ? context.l10n.preventionStatusAgree : future ? context.l10n.preventionStatusScheduled : context.l10n.preventionStatusPlan;
    return M24Card(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      PreventionDate(item: item), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(preventionRecommendationText(context.l10n, item.titleKey), style: context.m24.text.title),
        Text(preventionRecommendationReason(context.l10n, item.reasonKey), style: context.m24.text.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
        if (item.dueAt != null) Text(DateFormat.yMMMMd(Localizations.localeOf(context).toLanguageTag()).format(item.dueAt!), style: context.m24.text.bodySmall),
        const SizedBox(height: 8), M24StatusPill(label: state, variant: future ? M24StatusPillVariant.info : visitWithoutInterval ? M24StatusPillVariant.neutral : M24StatusPillVariant.warning),
        const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: <Widget>[M24Button(label: context.l10n.preventionExamDone, icon: M24Icons.confirm, size: M24ButtonSize.small, variant: M24ButtonVariant.secondary, onPressed: onComplete), M24Button(label: context.l10n.preventionIgnore, size: M24ButtonSize.small, variant: M24ButtonVariant.tertiary, onPressed: onDismiss)]),
      ])),
    ]));
  }
}

class PreventionDate extends StatelessWidget {
  const PreventionDate({super.key, required this.item});
  final PreventionRecommendation item;
  @override
  Widget build(BuildContext context) {
    if (item.dueAt == null) return M24DateTile(day: '--', month: item.category.toLowerCase().contains('visit') ? context.l10n.preventionAgreeShort : context.l10n.preventionPlanShort, variant: M24DateTileVariant.neutral);
    return M24DateTile(day: DateFormat.d().format(item.dueAt!), month: DateFormat.MMM(Localizations.localeOf(context).toLanguageTag()).format(item.dueAt!), variant: item.dueAt!.isAfter(DateTime.now()) ? M24DateTileVariant.primary : M24DateTileVariant.warning);
  }
}

class RiskCard extends StatefulWidget {
  const RiskCard({super.key, required this.family, required this.score, required this.history, required this.names, required this.onHistory, required this.onCompleteData});
  final RiskFamily family;
  final RiskScore? score;
  final List<RiskScore> history;
  final Map<String, Map<String, String>> names;
  final VoidCallback onHistory;
  final VoidCallback onCompleteData;
  @override
  State<RiskCard> createState() => _RiskCardState();
}

class _RiskCardState extends State<RiskCard> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final RiskScore? score = widget.score;
    return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Row(children: <Widget>[M24IconTile(icon: preventionFamilyIcon(widget.family), variant: score == null ? M24IconTileVariant.neutral : riskIconVariant(score.level)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(preventionFamilyTitle(context.l10n, widget.family), style: context.m24.text.h3), Text(preventionRuleName(context.l10n, widget.family), style: context.m24.text.caption)])), if (score != null) riskPill(context, score.level)]),
      const SizedBox(height: 14),
      if (score == null) ...<Widget>[
        Text(context.l10n.preventionDataIncomplete, style: context.m24.text.title), const SizedBox(height: 6), Text(preventionMissingData(context.l10n, widget.family), style: context.m24.text.bodySmall), const SizedBox(height: 12), M24Button(label: context.l10n.preventionCompleteData, onPressed: widget.onCompleteData, variant: M24ButtonVariant.secondary),
      ] else ...<Widget>[
        Text(preventionScore(context, score), style: context.m24.text.display),
        Text(context.l10n.preventionCalculatedOn(DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(score.computedAt)), style: context.m24.text.caption),
        if (score.projectionScore != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.l10n.preventionProjection(preventionNumber(context, score.projectionScore!)), style: context.m24.text.bodySmall)),
        if (score.ruleVersion.contains('-draft')) Padding(padding: const EdgeInsets.only(top: 8), child: Align(alignment: Alignment.centerLeft, child: M24StatusPill(label: context.l10n.preventionRuleDraft, variant: M24StatusPillVariant.neutral))),
        const SizedBox(height: 8), InkWell(onTap: () => setState(() => expanded = !expanded), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: <Widget>[Expanded(child: Text(context.l10n.preventionWhy, style: context.m24.text.label.copyWith(color: context.m24.colors.primary))), Icon(expanded ? M24Icons.chevronUp : M24Icons.chevronDown, color: context.m24.colors.primary)]))),
        if (expanded) ...score.factors.map((String factor) => PreventionFactorRow(factor: factor, value: score.inputs[factor], names: widget.names)),
        M24Button(label: context.l10n.preventionOpenHistory, icon: M24Icons.chart, variant: M24ButtonVariant.tertiary, onPressed: widget.onHistory),
      ],
      if (widget.family == RiskFamily.fracture) ...<Widget>[const SizedBox(height: 8), SelectableText(context.l10n.preventionFraxLink, style: context.m24.text.label.copyWith(color: context.m24.colors.info)), Text(context.l10n.preventionFraxPrivacy, style: context.m24.text.caption)],
      const SizedBox(height: 12), M24Disclaimer(phoneText: context.l10n.preventionRiskDisclaimer, desktopText: context.l10n.preventionRiskDisclaimer),
    ]));
  }
}

class PreventionFactorRow extends StatelessWidget {
  const PreventionFactorRow({super.key, required this.factor, required this.value, required this.names});
  final String factor;
  final dynamic value;
  final Map<String, Map<String, String>> names;
  @override
  Widget build(BuildContext context) {
    final String language = Localizations.localeOf(context).languageCode;
    final String label = names[factor]?[language] ?? preventionFactorLabel(context.l10n, factor);
    final String shown = value is bool ? (value ? context.l10n.commonYes : context.l10n.commonNo) : value?.toString() ?? context.l10n.preventionNotAvailable;
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Icon(M24Icons.confirm, size: 18, color: context.m24.colors.primary), const SizedBox(width: 8), Expanded(child: Text('$label: $shown', style: context.m24.text.bodySmall))]));
  }
}

class RiskHistoryChart extends StatelessWidget {
  const RiskHistoryChart({super.key, required this.family, required this.points});
  final RiskFamily family;
  final List<RiskScore> points;
  @override
  Widget build(BuildContext context) {
    final List<RiskScore> filtered = points.where((RiskScore item) => item.family == family).toList()..sort((RiskScore a, RiskScore b) => a.computedAt.compareTo(b.computedAt));
    if (filtered.isEmpty) return Text(context.l10n.preventionNoHistory);
    return SizedBox(height: 180, child: LineChart(LineChartData(borderData: FlBorderData(show: false), gridData: M24ChartStyle.grid(context), titlesData: const FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))), lineBarsData: <LineChartBarData>[M24ChartStyle.line(context, <FlSpot>[for (int i = 0; i < filtered.length; i++) FlSpot(i.toDouble(), filtered[i].score)])])));
  }
}

IconData preventionFamilyIcon(RiskFamily family) => switch (family) { RiskFamily.cardiovascular => M24Icons.health, RiskFamily.diabetes => M24Icons.chart, RiskFamily.kidney => M24Icons.ruler, RiskFamily.fracture => M24Icons.profile };
M24IconTileVariant riskIconVariant(RiskLevel level) => switch (level) { RiskLevel.low => M24IconTileVariant.success, RiskLevel.medium => M24IconTileVariant.warning, RiskLevel.high => M24IconTileVariant.danger };
M24StatusPill riskPill(BuildContext context, RiskLevel level) => M24StatusPill(label: switch (level) { RiskLevel.low => context.l10n.preventionRiskLow, RiskLevel.medium => context.l10n.preventionRiskMedium, RiskLevel.high => context.l10n.preventionRiskHigh }, variant: switch (level) { RiskLevel.low => M24StatusPillVariant.success, RiskLevel.medium => M24StatusPillVariant.warning, RiskLevel.high => M24StatusPillVariant.danger });
String preventionNumber(BuildContext context, double value) => NumberFormat.decimalPatternDigits(locale: Localizations.localeOf(context).toLanguageTag(), decimalDigits: value % 1 == 0 ? 0 : 1).format(value);
String preventionScore(BuildContext context, RiskScore score) => switch (score.scoreUnit) { 'percent_10y' => context.l10n.preventionScorePercent(preventionNumber(context, score.score)), 'points' => context.l10n.preventionScorePoints(preventionNumber(context, score.score)), 'mL/min/{1.73_m2}' => context.l10n.preventionScoreEgfr(preventionNumber(context, score.score)), _ => context.l10n.preventionScoreFactors(preventionNumber(context, score.score)) };
String preventionFamilyTitle(AppLocalizations l, RiskFamily family) => switch (family) { RiskFamily.cardiovascular => l.preventionFamilyCardio, RiskFamily.diabetes => l.preventionFamilyDiabetes, RiskFamily.kidney => l.preventionFamilyKidney, RiskFamily.fracture => l.preventionFamilyFracture };
String preventionRuleName(AppLocalizations l, RiskFamily family) => switch (family) { RiskFamily.cardiovascular => 'SCORE2', RiskFamily.diabetes => 'FINDRISC', RiskFamily.kidney => 'CKD-EPI 2021', RiskFamily.fracture => l.preventionFractureRule };
String preventionMissingData(AppLocalizations l, RiskFamily family) => switch (family) { RiskFamily.cardiovascular => l.preventionMissingCardio, RiskFamily.diabetes => l.preventionMissingQuestionnaire, RiskFamily.kidney => l.preventionMissingKidney, RiskFamily.fracture => l.preventionMissingQuestionnaire };
String preventionFactorLabel(AppLocalizations l, String key) => switch (key) { 'smoker' => l.questionSmoker, 'waist_cm' => l.questionWaist, 'bmi' => l.questionBmi, 'age' => l.preventionFactorAge, 'sex' => l.preventionFactorSex, _ => key.replaceAll('_', ' ') };

String preventionRecommendationText(AppLocalizations l, String key) => switch (key) {
  'recommendation_screening_mammografia' => l.recommendationScreeningMammografia,
  'recommendation_screening_cervice_pap' => l.recommendationScreeningCervicePap,
  'recommendation_screening_cervice_hpv' => l.recommendationScreeningCerviceHpv,
  'recommendation_screening_colon' => l.recommendationScreeningColon,
  'recommendation_pressione' => l.recommendationPressione,
  'recommendation_lipidi' => l.recommendationLipidi,
  'recommendation_glicemia' => l.recommendationGlicemia,
  'recommendation_peso_bmi' => l.recommendationPesoBmi,
  'recommendation_vista' => l.recommendationVista,
  'recommendation_udito' => l.recommendationUdito,
  'recommendation_dentista' => l.recommendationDentista,
  'recommendation_dermatologo' => l.recommendationDermatologo,
  'recommendation_vaccino_influenza' => l.recommendationVaccinoInfluenza,
  'recommendation_vaccino_pneumococco' => l.recommendationVaccinoPneumococco,
  'recommendation_vaccino_zoster' => l.recommendationVaccinoZoster,
  'recommendation_vaccino_tetano' => l.recommendationVaccinoTetano,
  'recommendation_psa' => l.recommendationPsa,
  'recommendation_densitometria' => l.recommendationDensitometria,
  'recommendation_aaa' => l.recommendationAaa,
  'recommendation_glicemia_findrisc' => l.recommendationGlicemiaFindrisc,
  'recommendation_lipidi_score2' => l.recommendationLipidiScore2,
  'recommendation_visita_cardiologica_score2' => l.recommendationVisitaCardiologicaScore2,
  'recommendation_visita_nefrologica_egfr' => l.recommendationVisitaNefrologicaEgfr,
  'recommendation_creatinina_egfr' => l.recommendationCreatininaEgfr,
  'recommendation_densitometria_frattura' => l.recommendationDensitometriaFrattura,
  'recommendation_level_improved' => l.recommendationLevelImproved,
  _ => key.replaceAll('_', ' '),
};

String preventionRecommendationReason(AppLocalizations l, String key) => switch (key) {
  'recommendation_screening_mammografia_reason' => l.recommendationScreeningMammografiaReason,
  'recommendation_screening_cervice_pap_reason' => l.recommendationScreeningCervicePapReason,
  'recommendation_screening_cervice_hpv_reason' => l.recommendationScreeningCerviceHpvReason,
  'recommendation_screening_colon_reason' => l.recommendationScreeningColonReason,
  'recommendation_pressione_reason' => l.recommendationPressioneReason,
  'recommendation_lipidi_reason' => l.recommendationLipidiReason,
  'recommendation_glicemia_reason' => l.recommendationGlicemiaReason,
  'recommendation_peso_bmi_reason' => l.recommendationPesoBmiReason,
  'recommendation_vista_reason' => l.recommendationVistaReason,
  'recommendation_udito_reason' => l.recommendationUditoReason,
  'recommendation_dentista_reason' => l.recommendationDentistaReason,
  'recommendation_dermatologo_reason' => l.recommendationDermatologoReason,
  'recommendation_vaccino_influenza_reason' => l.recommendationVaccinoInfluenzaReason,
  'recommendation_vaccino_pneumococco_reason' => l.recommendationVaccinoPneumococcoReason,
  'recommendation_vaccino_zoster_reason' => l.recommendationVaccinoZosterReason,
  'recommendation_vaccino_tetano_reason' => l.recommendationVaccinoTetanoReason,
  'recommendation_psa_reason' => l.recommendationPsaReason,
  'recommendation_densitometria_reason' => l.recommendationDensitometriaReason,
  'recommendation_aaa_reason' => l.recommendationAaaReason,
  'recommendation_glicemia_findrisc' => l.recommendationGlicemiaFindriscReason,
  'recommendation_lipidi_score2' => l.recommendationLipidiScore2Reason,
  'recommendation_visita_cardiologica_score2' => l.recommendationVisitaCardiologicaScore2Reason,
  'recommendation_visita_nefrologica_egfr' => l.recommendationVisitaNefrologicaEgfrReason,
  'recommendation_creatinina_egfr' => l.recommendationCreatininaEgfrReason,
  'recommendation_densitometria_frattura' => l.recommendationDensitometriaFratturaReason,
  'recommendation_level_improved' => l.recommendationLevelImproved,
  _ => key.replaceAll('_', ' '),
};