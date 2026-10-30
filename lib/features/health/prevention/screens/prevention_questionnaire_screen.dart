import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/health/prevention/data/prevention_models.dart';
import 'package:medical24/features/health/prevention/providers/prevention_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class PreventionQuestionnaireScreen extends ConsumerWidget {
  const PreventionQuestionnaireScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(preventionSnapshotProvider).when(data: (PreventionSnapshot snapshot) => PreventionQuestionnaireForm(questionnaire: snapshot.questionnaire), loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: context.l10n.preventionLoadError, onRetry: () => ref.invalidate(preventionSnapshotProvider)));
}

class PreventionQuestionnaireForm extends ConsumerStatefulWidget {
  const PreventionQuestionnaireForm({super.key, required this.questionnaire, this.onSaved});
  final QuestionnaireState questionnaire;
  final VoidCallback? onSaved;
  @override
  ConsumerState<PreventionQuestionnaireForm> createState() => _PreventionQuestionnaireFormState();
}

class _PreventionQuestionnaireFormState extends ConsumerState<PreventionQuestionnaireForm> {
  late final Map<String, dynamic> answers;
  late final TextEditingController waist;
  late final TextEditingController height;
  late final TextEditingController weight;
  late final TextEditingController bmd;
  int step = 0;
  bool saving = false;
  String? saveError;

  static const List<String> _booleanKeys = <String>['smoker', 'physical_activity_30min_daily', 'vegetables_fruit_daily', 'alcohol_3_units_daily', 'antihypertensive_medication', 'history_high_glucose', 'previous_fracture', 'parent_hip_fracture', 'glucocorticoids', 'rheumatoid_arthritis', 'secondary_osteoporosis'];

  @override
  void initState() {
    super.initState();
    answers = Map<String, dynamic>.from(widget.questionnaire.answers);
    for (final String key in _booleanKeys) answers.putIfAbsent(key, () => false);
    answers.putIfAbsent('family_diabetes', () => 'none');
    waist = _controller('waist_cm');
    height = _controller('height_cm');
    weight = TextEditingController(text: answers['weight_kg']?.toString() ?? widget.questionnaire.latestWeightKg?.toString() ?? '');
    bmd = _controller('bmd_t_score');
  }

  TextEditingController _controller(String key) => TextEditingController(text: answers[key]?.toString() ?? '');

  @override
  void dispose() {
    waist.dispose();
    height.dispose();
    weight.dispose();
    bmd.dispose();
    super.dispose();
  }

  double? _number(TextEditingController controller) => double.tryParse(controller.text.trim().replaceAll(',', '.'));
  double? get bmi {
    final double? cm = _number(height);
    final double? kg = _number(weight);
    if (cm == null || cm <= 0 || kg == null || kg <= 0) return null;
    return kg / ((cm / 100) * (cm / 100));
  }

  List<String> _missing(BuildContext context) {
    if (step != 2) return const <String>[];
    return <String>[if ((_number(waist) ?? 0) <= 0) context.l10n.questionWaist, if ((_number(height) ?? 0) <= 0) context.l10n.questionHeight, if ((_number(weight) ?? 0) <= 0) context.l10n.questionWeight];
  }

  @override
  Widget build(BuildContext context) {
    final List<String> titles = <String>[context.l10n.questionGroupLifestyle, context.l10n.questionGroupFamily, context.l10n.questionGroupMeasures, context.l10n.questionGroupBones];
    final List<String> missing = _missing(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(appBar: AppBar(leading: IconButton(icon: const Icon(M24Icons.back), onPressed: () => context.pop()), title: Text(context.l10n.preventionQuestionnaireTitle)), body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Padding(padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width >= 600 ? 24 : 16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      const SizedBox(height: 16),
      if (widget.questionnaire.submittedAt != null) Text('${context.l10n.questionnaireLastCompleted(DateFormat.yMMMd(locale).format(widget.questionnaire.submittedAt!))} · ${context.l10n.questionnaireUpdate}', style: context.m24.text.bodySmall),
      if (widget.questionnaire.submittedAt != null) const SizedBox(height: 8),
      Text(context.l10n.questionnaireStep(step + 1, titles[step]), style: context.m24.text.title), const SizedBox(height: 8), LinearProgressIndicator(value: (step + 1) / 4), const SizedBox(height: 16),
      if (saveError != null) ...<Widget>[M24Banner(title: context.l10n.commonErrorTitle, subtitle: saveError!), const SizedBox(height: 8), Align(alignment: Alignment.centerLeft, child: M24Button(label: context.l10n.commonRetry, variant: M24ButtonVariant.tertiary, onPressed: _save)), const SizedBox(height: 8)],
      Expanded(child: SingleChildScrollView(child: M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Text(titles[step], style: context.m24.text.h2), const SizedBox(height: 12),
        if (step == 0) ...<Widget>[BooleanQuestion(label: context.l10n.questionSmoker, value: answers['smoker'] as bool, onChanged: (bool value) => setState(() => answers['smoker'] = value)), BooleanQuestion(label: context.l10n.questionPhysicalActivity, value: answers['physical_activity_30min_daily'] as bool, onChanged: (bool value) => setState(() => answers['physical_activity_30min_daily'] = value)), BooleanQuestion(label: context.l10n.questionFruitVegetables, value: answers['vegetables_fruit_daily'] as bool, onChanged: (bool value) => setState(() => answers['vegetables_fruit_daily'] = value)), BooleanQuestion(label: context.l10n.questionAlcohol, value: answers['alcohol_3_units_daily'] as bool, onChanged: (bool value) => setState(() => answers['alcohol_3_units_daily'] = value))],
        if (step == 1) ...<Widget>[BooleanQuestion(label: context.l10n.questionAntihypertensive, value: answers['antihypertensive_medication'] as bool, onChanged: (bool value) => setState(() => answers['antihypertensive_medication'] = value)), BooleanQuestion(label: context.l10n.questionHighGlucose, value: answers['history_high_glucose'] as bool, onChanged: (bool value) => setState(() => answers['history_high_glucose'] = value)), ChoiceQuestion(label: context.l10n.questionFamilyDiabetes, value: answers['family_diabetes'].toString(), choices: <String, String>{'none': context.l10n.questionFamilyNone, 'second_degree': context.l10n.questionFamilySecond, 'first_degree': context.l10n.questionFamilyFirst}, onChanged: (String value) => setState(() => answers['family_diabetes'] = value))],
        if (step == 2) ...<Widget>[NumericQuestion(fieldKey: const ValueKey<String>('waist-field'), label: context.l10n.questionWaist, unit: 'cm', controller: waist, onChanged: (_) => setState(() {})), NumericQuestion(fieldKey: const ValueKey<String>('height-field'), label: context.l10n.questionHeight, unit: 'cm', controller: height, onChanged: (_) => setState(() {})), NumericQuestion(fieldKey: const ValueKey<String>('weight-field'), label: context.l10n.questionWeight, unit: 'kg', controller: weight, onChanged: (_) => setState(() {})), if (widget.questionnaire.latestWeightAt != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(context.l10n.questionWeightRecorded(DateFormat.yMMMd(locale).format(widget.questionnaire.latestWeightAt!)), style: context.m24.text.caption)), Text(bmi == null ? context.l10n.questionBmiUnavailable : context.l10n.questionBmiValue(NumberFormat('0.0', locale).format(bmi)), key: const ValueKey<String>('bmi-value'), style: context.m24.text.title)],
        if (step == 3) ...<Widget>[BooleanQuestion(label: context.l10n.questionPreviousFracture, value: answers['previous_fracture'] as bool, onChanged: (bool value) => setState(() => answers['previous_fracture'] = value)), BooleanQuestion(label: context.l10n.questionParentHipFracture, value: answers['parent_hip_fracture'] as bool, onChanged: (bool value) => setState(() => answers['parent_hip_fracture'] = value)), BooleanQuestion(label: context.l10n.questionGlucocorticoids, value: answers['glucocorticoids'] as bool, onChanged: (bool value) => setState(() => answers['glucocorticoids'] = value)), BooleanQuestion(label: context.l10n.questionRheumatoid, value: answers['rheumatoid_arthritis'] as bool, onChanged: (bool value) => setState(() => answers['rheumatoid_arthritis'] = value)), BooleanQuestion(label: context.l10n.questionSecondaryOsteoporosis, value: answers['secondary_osteoporosis'] as bool, onChanged: (bool value) => setState(() => answers['secondary_osteoporosis'] = value)), NumericQuestion(label: context.l10n.questionBmd, unit: 'T-score', controller: bmd, optional: true), const SizedBox(height: 8), QuestionnaireSummary(height: _number(height), weight: _number(weight), waist: _number(waist), bmi: bmi)],
      ])))),
      const SizedBox(height: 12),
      if (step > 0) Align(alignment: Alignment.centerLeft, child: M24Button(label: context.l10n.commonBack, variant: M24ButtonVariant.tertiary, onPressed: saving ? null : () => setState(() { step--; saveError = null; }))),
      if (step > 0) const SizedBox(height: 8),
      M24Button(label: step == 3 ? context.l10n.questionnaireSave : context.l10n.questionnaireNext, icon: step == 3 ? LucideIcons.check : LucideIcons.arrowRight, size: M24ButtonSize.large, loading: saving, onPressed: saving || missing.isNotEmpty ? null : step < 3 ? () => setState(() { step++; saveError = null; }) : _save),
      if (missing.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.l10n.questionnaireMissing(missing.join(', ')), style: context.m24.text.bodySmall.copyWith(color: context.m24.colors.warningInk))),
      const SizedBox(height: 16),
    ]))))));
  }

  Future<void> _save() async {
    final double? waistValue = _number(waist);
    final double? heightValue = _number(height);
    final double? weightValue = _number(weight);
    final double? bmdValue = _number(bmd);
    if (waistValue == null || heightValue == null || weightValue == null || bmi == null) return;
    answers['waist_cm'] = waistValue;
    answers['height_cm'] = heightValue;
    answers['weight_kg'] = weightValue;
    answers['bmi'] = double.parse(bmi!.toStringAsFixed(1));
    if (bmdValue != null) answers['bmd_t_score'] = bmdValue; else answers.remove('bmd_t_score');
    setState(() { saving = true; saveError = null; });
    try {
      final bool weightSaved = await ref.read(preventionActionsProvider).saveAnswers(answers, widget.questionnaire.version, weightValue);
      if (!mounted) return;
      widget.onSaved?.call();
      if (widget.onSaved == null) context.go('${AppRoutes.prevention}?tab=risks');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(weightSaved ? context.l10n.questionnaireSaved : context.l10n.questionnaireSavedWeightWarning)));
    } catch (error) {
      if (mounted) setState(() => saveError = AppFailure.from(error, where: 'save prevention questionnaire').localized(Localizations.localeOf(context).languageCode));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class BooleanQuestion extends StatelessWidget {
  const BooleanQuestion({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('$label *'), value: value, onChanged: onChanged);
}

class NumericQuestion extends StatelessWidget {
  const NumericQuestion({super.key, required this.label, required this.unit, required this.controller, this.fieldKey, this.onChanged, this.optional = false});
  final String label, unit;
  final TextEditingController controller;
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;
  final bool optional;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(key: fieldKey, controller: controller, onChanged: onChanged, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: optional ? '$label (${context.l10n.commonOptional})' : '$label *', suffixText: unit)));
}

class ChoiceQuestion extends StatelessWidget {
  const ChoiceQuestion({super.key, required this.label, required this.value, required this.choices, required this.onChanged});
  final String label;
  final String value;
  final Map<String, String> choices;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text('$label *', style: context.m24.text.title), ...choices.entries.map((MapEntry<String, String> item) => RadioListTile<String>(contentPadding: EdgeInsets.zero, title: Text(item.value), value: item.key, groupValue: value, onChanged: (String? next) { if (next != null) onChanged(next); }))]);
}

class QuestionnaireSummary extends StatelessWidget {
  const QuestionnaireSummary({super.key, required this.height, required this.weight, required this.waist, required this.bmi});
  final double? height, weight, waist, bmi;
  @override
  Widget build(BuildContext context) {
    final NumberFormat format = NumberFormat('0.0', Localizations.localeOf(context).toLanguageTag());
    return M24Card(tint: M24CardTint.primary, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(context.l10n.questionnaireSummary, style: context.m24.text.title), const SizedBox(height: 6), Text(context.l10n.questionnaireSummaryMeasures(format.format(height), format.format(weight), format.format(waist), format.format(bmi)), style: context.m24.text.bodySmall)]));
  }
}