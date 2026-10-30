import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/core/models/biomarker.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/features/analysis/providers/analysis_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';

/// Review queue. Enter confirms and C opens correction on desktop.
class ObservationReview extends ConsumerStatefulWidget {
  const ObservationReview({super.key, required this.observations, required this.catalog});

  final List<Observation> observations;
  final Map<String, Biomarker> catalog;

  static Future<void> showPhone(BuildContext context, List<Observation> observations, Map<String, Biomarker> catalog) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (BuildContext context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          maxChildSize: 0.96,
          builder: (BuildContext context, ScrollController controller) => ObservationReview(observations: observations, catalog: catalog),
        ),
      );

  @override
  ConsumerState<ObservationReview> createState() => _ObservationReviewState();
}

class _ObservationReviewState extends ConsumerState<ObservationReview> {
  int _index = 0;
  final FocusNode _focus = FocusNode();

  Observation get _current => widget.observations[_index.clamp(0, widget.observations.length - 1)];

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    await ref.read(analysisControllerProvider.notifier).confirm(_current);
    _advance();
  }

  void _advance() {
    if (!mounted) return;
    if (_index + 1 < widget.observations.length) {
      setState(() => _index++);
    } else if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _correct() async {
    final Biomarker? biomarker = widget.catalog[_current.code];
    final ({double value, String unit})? correction = await showDialog<({double value, String unit})>(
      context: context,
      builder: (BuildContext context) => ObservationCorrectionDialog(observation: _current, biomarker: biomarker),
    );
    if (correction == null) return;
    await ref.read(analysisControllerProvider.notifier).correct(_current, valueNum: correction.value, unit: correction.unit);
    _advance();
  }

  Future<void> _discard() async {
    await ref.read(analysisControllerProvider.notifier).discard(_current);
    _advance();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || ref.read(analysisControllerProvider).isLoading) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _confirm();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyC) {
      _correct();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.observations.isEmpty) return Center(child: Text(context.l10n.t('analysisReviewComplete')));
    final Observation observation = _current;
    final Biomarker? biomarker = widget.catalog[observation.code];
    final bool busy = ref.watch(analysisControllerProvider).isLoading;
    ref.listen<AsyncValue<void>>(analysisControllerProvider, (_, AsyncValue<void> next) {
      if (next.hasError) {
        final String language = Localizations.localeOf(context).languageCode;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppFailure.from(next.error!, where: 'analysis.review').localized(language))));
      }
    });
    return Focus(
      autofocus: true,
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text(context.l10n.t('analysisReviewTitle'), style: Theme.of(context).textTheme.headlineSmall)),
            Text('${_index + 1} / ${widget.observations.length}'),
          ]),
          const SizedBox(height: 8),
          Text(context.l10n.t('analysisReviewBody')),
          const SizedBox(height: 24),
          M24Card(tint: M24CardTint.warning, child: Padding(
            padding: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(biomarker?.name(Localizations.localeOf(context).languageCode) ?? observation.displayName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(context.l10n.t('analysisReadAs', args: <String, String>{'value': observation.displayValue()})),
              if (observation.confidence != null) Text(context.l10n.t('analysisConfidence', args: <String, String>{'percent': '${(observation.confidence! * 100).round()}'})),
              const SizedBox(height: 16),
              Row(children: <Widget>[
                const Icon(LucideIcons.imageOff),
                const SizedBox(width: 8),
                Expanded(child: Text(context.l10n.t('analysisSourceUnavailable'))),
              ]),
            ]),
          )),
          const SizedBox(height: 20),
          M24Button(label: context.l10n.t('analysisConfirmAction'), icon: M24Icons.confirm, onPressed: busy ? null : _confirm),
          const SizedBox(height: 8),
          M24Button(label: context.l10n.t('analysisCorrectAction'), icon: LucideIcons.pencil, variant: M24ButtonVariant.outline, onPressed: busy ? null : _correct),
          const SizedBox(height: 8),
          M24Button(label: context.l10n.t('analysisDiscardAction'), icon: M24Icons.discard, variant: M24ButtonVariant.outline, onPressed: busy ? null : _discard),
          if (busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          const SizedBox(height: 16),
          Text(context.l10n.t('analysisKeyboardHelp'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

/// Correction form constrained to units declared by the catalog.
class ObservationCorrectionDialog extends StatefulWidget {
  const ObservationCorrectionDialog({super.key, required this.observation, required this.biomarker});

  final Observation observation;
  final Biomarker? biomarker;

  @override
  State<ObservationCorrectionDialog> createState() => _ObservationCorrectionDialogState();
}

class _ObservationCorrectionDialogState extends State<ObservationCorrectionDialog> {
  late final TextEditingController _value;
  late String _unit;

  List<String> get _units {
    final Set<String> values = <String>{
      if ((widget.biomarker?.unitCanonical ?? '').isNotEmpty) widget.biomarker!.unitCanonical,
      ...?widget.biomarker?.unitAlternatives.keys,
    };
    if (values.isEmpty && (widget.observation.unit ?? '').isNotEmpty) values.add(widget.observation.unit!);
    return values.toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _value = TextEditingController(text: widget.observation.valueNum?.toString() ?? '');
    _unit = _units.contains(widget.observation.unit) ? widget.observation.unit! : (_units.isEmpty ? '' : _units.first);
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.t('analysisCorrectTitle')),
    content: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      TextField(controller: _value, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: context.l10n.t('analysisValueField'))),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _unit.isEmpty ? null : _unit,
        decoration: InputDecoration(labelText: context.l10n.t('analysisUnitField')),
        items: _units.map((String unit) => DropdownMenuItem<String>(value: unit, child: Text(unit))).toList(growable: false),
        onChanged: (String? value) {
          if (value != null) setState(() => _unit = value);
        },
      ),
    ]),
    actions: <Widget>[
      TextButton(onPressed: () => context.pop(), child: Text(context.l10n.t('commonCancel'))),
      FilledButton(
        onPressed: () {
          final double? value = double.tryParse(_value.text.replaceAll(',', '.'));
          if (value != null && _unit.isNotEmpty) context.pop((value: value, unit: _unit));
        },
        child: Text(context.l10n.t('commonSave')),
      ),
    ],
  );
}