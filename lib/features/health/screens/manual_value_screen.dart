import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medical24/core/providers/app_providers.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/formatters.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/health/data/health_models.dart';
import 'package:medical24/features/health/data/health_repository.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

const String systolicCode = '8480-6';
const String diastolicCode = '8462-4';

class ManualValueScreen extends StatelessWidget {
  const ManualValueScreen({super.key, this.initialCode});
  final String? initialCode;

  @override
  Widget build(BuildContext context) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    final Widget form = ManualValueForm(initialCode: initialCode);
    if (desktop) return SectionPage(title: context.l10n.t('healthManualTitle'), subtitle: context.l10n.t('healthManualSubtitle'), showDisclaimer: true, child: Align(alignment: Alignment.topCenter, child: SizedBox(width: 480, child: form)));
    return Scaffold(appBar: M24DetailAppBar(title: context.l10n.t('healthManualTitle'), parentTitle: context.l10n.t('healthValuesTitle'), backTooltip: context.l10n.t('commonBack'), onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.health)), body: form);
  }
}

class ManualValueForm extends ConsumerStatefulWidget {
  const ManualValueForm({super.key, this.initialCode});
  final String? initialCode;

  @override
  ConsumerState<ManualValueForm> createState() => _ManualValueFormState();
}

class _ManualValueFormState extends ConsumerState<ManualValueForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _value = TextEditingController();
  final TextEditingController _diastolic = TextEditingController();
  String? _code;
  String? _unit;
  DateTime _effectiveAt = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _code = widget.initialCode;
  }

  @override
  void dispose() {
    _value.dispose();
    _diastolic.dispose();
    super.dispose();
  }

  ManualBiomarker? _find(List<ManualBiomarker> rows, String code) => rows.where((ManualBiomarker row) => row.code == code).firstOrNull;

  String? _validate(String? raw, ManualBiomarker biomarker) {
    final double? value = NumberFormat.decimalPattern(Localizations.localeOf(context).languageCode).tryParse(raw ?? '')?.toDouble();
    if (value == null) return context.l10n.t('healthManualNumberRequired');
    final double canonical = biomarker.canonicalValue(value, _unit ?? biomarker.canonicalUnit);
    if ((biomarker.plausibleMin != null && canonical < biomarker.plausibleMin!) || (biomarker.plausibleMax != null && canonical > biomarker.plausibleMax!)) {
      final String language = Localizations.localeOf(context).languageCode;
      return context.l10n.t('healthManualPlausibleRange', args: <String, String>{'min': biomarker.plausibleMin == null ? '–' : formatValue(biomarker.plausibleMin!, locale: language), 'max': biomarker.plausibleMax == null ? '–' : formatValue(biomarker.plausibleMax!, locale: language), 'unit': formatUnit(biomarker.canonicalUnit)});
    }
    return null;
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(context: context, initialDate: _effectiveAt, firstDate: DateTime(1900), lastDate: DateTime.now());
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_effectiveAt));
    if (time != null) setState(() => _effectiveAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  double _number(String raw) => NumberFormat.decimalPattern(Localizations.localeOf(context).languageCode).parse(raw).toDouble();

  Future<void> _save(List<ManualBiomarker> rows) async {
    if (!_formKey.currentState!.validate() || _code == null) return;
    final bool pressure = _code == systolicCode;
    final List<ManualObservationInput> values = <ManualObservationInput>[
      ManualObservationInput(code: _code!, value: _number(_value.text), unit: _unit!),
      if (pressure) ManualObservationInput(code: diastolicCode, value: _number(_diastolic.text), unit: _unit!),
    ];
    setState(() => _saving = true);
    try {
      await ref.read(healthRepositoryProvider).insertManualValues(values, _effectiveAt);
      ref.invalidate(healthCatalogProvider);
      ref.invalidate(healthHistoryProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.t('healthManualSaved'))));
      context.go(AppRoutes.healthValue(_code!));
    } on ManualValueException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.t('healthManualError_${error.code}'))));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.t('healthManualError_unknown'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ManualBiomarker>> catalog = ref.watch(manualBiomarkerCatalogProvider);
    return catalog.when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: context.l10n.t('healthValuesError'), onRetry: () => ref.invalidate(manualBiomarkerCatalogProvider)), data: (List<ManualBiomarker> rows) {
      final List<ManualBiomarker> choices = rows.where((ManualBiomarker row) => row.code != diastolicCode).toList(growable: false);
      _code ??= choices.firstOrNull?.code;
      ManualBiomarker? selected = _code == null ? null : _find(rows, _code!);
      if (selected == null && choices.isNotEmpty) {
        _code = choices.first.code;
        selected = choices.first;
      }
      if (selected == null) return M24EmptyState(icon: M24Icons.manualValue, title: context.l10n.t('healthValuesEmptyTitle'), message: context.l10n.t('healthValuesEmptyBody'), actionLabel: context.l10n.t('commonBack'), onAction: () => context.go(AppRoutes.health));
      final ManualBiomarker selectedValue = selected;
      _unit ??= selectedValue.code == '2345-7' && (ref.watch(myProfileProvider).value?.units.contains('mmol') ?? false) && selectedValue.units.contains('mmol/L') ? 'mmol/L' : selectedValue.canonicalUnit;
      final ManualBiomarker? diastolic = _find(rows, diastolicCode);
      final String language = Localizations.localeOf(context).languageCode;
      return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: M24Card(child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Text(context.l10n.t('healthManualFormTitle'), style: context.m24.text.h2),
        Text(context.l10n.t('healthManualSubtitle'), style: context.m24.text.bodySmall),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(initialValue: _code, decoration: InputDecoration(labelText: context.l10n.t('healthManualParameter')), items: choices.map((ManualBiomarker row) => DropdownMenuItem<String>(value: row.code, child: Text(row.code == systolicCode ? context.l10n.t('healthManualPressure') : row.name(language)))).toList(growable: false), onChanged: (String? code) => setState(() { _code = code; _unit = null; _value.clear(); _diastolic.clear(); })),
        const SizedBox(height: 16),
        TextFormField(controller: _value, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))], decoration: InputDecoration(labelText: _code == systolicCode ? context.l10n.t('healthManualSystolic') : context.l10n.t('healthManualValue')), validator: (String? raw) => _validate(raw, selectedValue)),
        if (_code == systolicCode && diastolic != null) ...<Widget>[const SizedBox(height: 16), TextFormField(controller: _diastolic, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: context.l10n.t('healthManualDiastolic')), validator: (String? raw) => _validate(raw, diastolic))],
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(initialValue: _unit, decoration: InputDecoration(labelText: context.l10n.t('healthManualUnit')), items: selectedValue.units.map((String unit) => DropdownMenuItem<String>(value: unit, child: Text(formatUnit(unit)))).toList(growable: false), onChanged: (String? unit) => setState(() => _unit = unit)),
        const SizedBox(height: 16),
        M24Button(label: DateFormat.yMd(language).add_Hm().format(_effectiveAt), icon: M24Icons.calendar, onPressed: _pickDateTime, variant: M24ButtonVariant.outline),
        const SizedBox(height: 24),
        M24Button(label: context.l10n.t('commonSave'), icon: M24Icons.confirm, onPressed: _saving ? null : () => _save(rows), loading: _saving, size: M24ButtonSize.large),
      ]))))));
    });
  }
}