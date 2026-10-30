import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/health/data/symptom_models.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class SymptomFormScreen extends ConsumerWidget {
  const SymptomFormScreen({super.key, this.id});
  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id == null) return const SymptomForm();
    return ref.watch(symptomProvider(id!)).when(loading: () => const Scaffold(body: AppLoadingView()), error: (Object error, StackTrace _) => Scaffold(body: AppErrorView(message: context.l10n.t('symptomsLoadError'))), data: (SymptomEntry? entry) => entry == null ? Scaffold(body: AppEmptyView(body: context.l10n.t('symptomsMissing'))) : SymptomForm(entry: entry));
  }
}

class SymptomForm extends ConsumerStatefulWidget {
  const SymptomForm({super.key, this.entry});
  final SymptomEntry? entry;
  @override
  ConsumerState<SymptomForm> createState() => _SymptomFormState();
}

class _SymptomFormState extends ConsumerState<SymptomForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String? _code = widget.entry?.code;
  late final TextEditingController _free = TextEditingController(text: widget.entry?.freeText);
  late final TextEditingController _notes = TextEditingController(text: widget.entry?.notes);
  late double _severity = (widget.entry?.severity ?? 1).toDouble();
  late DateTime _occurredAt = widget.entry?.occurredAt ?? DateTime.now();
  bool _saving = false;
  bool get _readOnly => widget.entry != null && !widget.entry!.editableAt(DateTime.now());

  @override
  void dispose() { _free.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(context: context, initialDate: _occurredAt, firstDate: DateTime(2000), lastDate: DateTime.now());
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_occurredAt));
    if (time != null) setState(() => _occurredAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final SymptomInput input = SymptomInput(code: _code == 'other' ? null : _code, freeText: _code == null || _code == 'other' ? _free.text.trim() : null, severity: _severity.round(), notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(), occurredAt: _occurredAt);
    try {
      if (widget.entry == null) await ref.read(symptomsRepositoryProvider).create(input); else await ref.read(symptomsRepositoryProvider).update(widget.entry!.id, input);
      ref.invalidate(symptomsProvider);
      if (mounted) context.pop();
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.t('symptomsSaveError')))); }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete() async {
    final bool? confirm = await showDialog<bool>(context: context, builder: (BuildContext context) => AlertDialog(title: Text(context.l10n.t('symptomsDeleteTitle')), content: Text(context.l10n.t('symptomsDeleteBody')), actions: <Widget>[TextButton(onPressed: () => context.pop(false), child: Text(context.l10n.t('commonCancel'))), FilledButton(onPressed: () => context.pop(true), child: Text(context.l10n.t('symptomsDelete')))]));
    if (confirm != true) return;
    await ref.read(symptomsRepositoryProvider).delete(widget.entry!.id);
    ref.invalidate(symptomsProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final String locale = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(appBar: M24DetailAppBar(title: context.l10n.t(widget.entry == null ? 'symptomsNew' : 'symptomsEdit'), parentTitle: context.l10n.t('symptomsTitle'), backTooltip: context.l10n.t('commonBack'), onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.symptoms)), body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: M24Card(child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      if (_readOnly) M24Card(tint: M24CardTint.warning, child: Text(context.l10n.t('symptomsReadOnly'), style: context.m24.text.bodySmall)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(initialValue: _code, decoration: InputDecoration(labelText: context.l10n.t('symptomsType')), items: <DropdownMenuItem<String>>[for (final String code in symptomCodes) DropdownMenuItem<String>(value: code, child: Text(context.l10n.t('symptom_$code')))], onChanged: _readOnly ? null : (String? value) => setState(() => _code = value)),
      if (_code == null || _code == 'other') ...<Widget>[const SizedBox(height: 16), TextFormField(controller: _free, readOnly: _readOnly, decoration: InputDecoration(labelText: context.l10n.t('symptomsFreeText')), validator: (String? value) => (_code == null || _code == 'other') && (value?.trim().isEmpty ?? true) ? context.l10n.t('commonRequired') : null)],
      const SizedBox(height: 24), Text('${context.l10n.t('symptomsSeverity')}: ${_severity.round()}', style: context.m24.text.title), Slider(value: _severity, min: 1, max: 5, divisions: 4, label: _severity.round().toString(), onChanged: _readOnly ? null : (double value) => setState(() => _severity = value)),
      TextFormField(controller: _notes, readOnly: _readOnly, maxLines: 3, decoration: InputDecoration(labelText: context.l10n.t('symptomsNotes'))),
      const SizedBox(height: 16), M24Button(label: DateFormat.yMd(locale).add_Hm().format(_occurredAt), icon: M24Icons.clock, onPressed: _readOnly ? null : _pickDateTime, variant: M24ButtonVariant.outline),
      const SizedBox(height: 24), if (!_readOnly) M24Button(label: context.l10n.t('commonSave'), icon: M24Icons.confirm, onPressed: _saving ? null : _save, loading: _saving, size: M24ButtonSize.large),
      if (widget.entry != null && !_readOnly) M24Button(label: context.l10n.t('symptomsDelete'), icon: LucideIcons.trash2, onPressed: _delete, variant: M24ButtonVariant.destructiveOutline),
    ])))))));
  }
}