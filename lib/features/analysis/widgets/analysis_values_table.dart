import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/core/models/biomarker.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';
import 'package:medical24/features/analysis/providers/analysis_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

typedef ObservationAction = Future<bool> Function(Observation observation);

/// Extracted values with review states, row actions, and bulk confirmation.
class AnalysisValuesTable extends ConsumerStatefulWidget {
  const AnalysisValuesTable({super.key, required this.observations, required this.catalog, this.compact = false, this.onApprove, this.onDiscard});

  final List<Observation> observations;
  final Map<String, Biomarker> catalog;
  final bool compact;
  final ObservationAction? onApprove;
  final ObservationAction? onDiscard;

  @override
  ConsumerState<AnalysisValuesTable> createState() => _AnalysisValuesTableState();
}

class _AnalysisValuesTableState extends ConsumerState<AnalysisValuesTable> {
  final Set<String> _busy = <String>{};
  bool _showDiscarded = false;
  int _bulkDone = 0;
  int _bulkTotal = 0;
  int? _bulkConfirmed;
  int? _bulkErrors;

  List<Observation> get _visible => widget.observations.where((Observation value) => _showDiscarded || !value.isDiscarded).toList(growable: false);
  List<Observation> get _pending => widget.observations.where((Observation value) => value.isPending).toList(growable: false);
  bool get _bulkLoading => _bulkTotal > 0 && _bulkDone < _bulkTotal;

  Future<bool> _approve(Observation observation) => widget.onApprove?.call(observation) ?? ref.read(analysisControllerProvider.notifier).confirm(observation);
  Future<bool> _discard(Observation observation) => widget.onDiscard?.call(observation) ?? ref.read(analysisControllerProvider.notifier).discard(observation);

  void _showError() {
    final Object error = ref.read(analysisControllerProvider).error ?? AppFailure.generic;
    final String language = Localizations.localeOf(context).languageCode;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppFailure.from(error, where: 'analysis.values').localized(language))));
  }

  Future<void> _runRow(Observation observation, ObservationAction action) async {
    setState(() => _busy.add(observation.id));
    try {
      final bool succeeded = await action(observation);
      if (!succeeded && mounted) _showError();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppFailure.from(error, where: 'analysis.values').localized(Localizations.localeOf(context).languageCode))));
    } finally {
      if (mounted) setState(() => _busy.remove(observation.id));
    }
  }

  Future<void> _confirmDiscard(Observation observation) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(context.l10n.t('analysisDiscardConfirmTitle')),
            content: Text(context.l10n.t('analysisDiscardConfirmBody')),
            actions: <Widget>[
              M24Button(label: context.l10n.t('commonCancel'), variant: M24ButtonVariant.tertiary, onPressed: () => dialogContext.pop(false)),
              M24Button(label: context.l10n.t('analysisDiscardAction'), variant: M24ButtonVariant.destructiveOutline, onPressed: () => dialogContext.pop(true)),
            ],
          ),
        ) ??
        false;
    if (confirmed) await _runRow(observation, _discard);
  }

  Future<void> _confirmAll() async {
    final List<Observation> values = _pending;
    setState(() { _bulkTotal = values.length; _bulkDone = 0; _bulkConfirmed = null; _bulkErrors = null; });
    int confirmed = 0;
    int errors = 0;
    for (final Observation observation in values) {
      setState(() => _busy.add(observation.id));
      try {
        if (await _approve(observation)) {
          confirmed++;
        } else {
          errors++;
        }
      } catch (_) {
        errors++;
      } finally {
        if (mounted) setState(() { _busy.remove(observation.id); _bulkDone++; });
      }
    }
    if (mounted) setState(() { _bulkConfirmed = confirmed; _bulkErrors = errors; });
  }

  @override
  Widget build(BuildContext context) {
    final List<Observation> values = _visible;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: <Widget>[
        if (_pending.isNotEmpty)
          M24Button(key: const Key('analysis-confirm-all'), label: context.l10n.t('analysisConfirmAll', args: <String, String>{'count': '${_pending.length}'}), icon: M24Icons.confirm, size: M24ButtonSize.small, loading: _bulkLoading, onPressed: _bulkLoading ? null : _confirmAll),
        Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(context.l10n.t('analysisShowDiscarded'), style: context.m24.text.bodySmall),
          Switch(value: _showDiscarded, onChanged: _bulkLoading ? null : (bool value) => setState(() => _showDiscarded = value)),
        ]),
      ]),
      if (_bulkTotal > 0) ...<Widget>[
        const SizedBox(height: 8),
        LinearProgressIndicator(key: const Key('analysis-confirm-all-progress'), value: _bulkTotal == 0 ? 0 : _bulkDone / _bulkTotal),
        const SizedBox(height: 6),
        Text(_bulkLoading ? context.l10n.t('analysisConfirmAllProgress', args: <String, String>{'current': '$_bulkDone', 'total': '$_bulkTotal'}) : context.l10n.t('analysisConfirmAllResult', args: <String, String>{'confirmed': '${_bulkConfirmed ?? 0}', 'errors': '${_bulkErrors ?? 0}'}), style: context.m24.text.caption),
      ],
      const SizedBox(height: 8),
      if (values.isEmpty)
        Padding(padding: const EdgeInsets.all(24), child: Text(context.l10n.t('analysisEmptyBody')))
      else
        LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
          final bool desktop = !widget.compact && constraints.maxWidth >= 760;
          return M24Card(padding: EdgeInsets.zero, child: Column(children: <Widget>[
            if (desktop) const AnalysisValuesHeader(),
            for (int i = 0; i < values.length; i++)
              AnalysisValueRow(
                observation: values[i],
                biomarker: widget.catalog[values[i].code],
                desktop: desktop,
                busy: _busy.contains(values[i].id),
                showDivider: i < values.length - 1,
                onApprove: values[i].isPending ? () => _runRow(values[i], _approve) : null,
                onDiscard: values[i].isDiscarded ? null : () => _confirmDiscard(values[i]),
              ),
          ]));
        }),
    ]);
  }
}

class AnalysisValuesHeader extends StatelessWidget {
  const AnalysisValuesHeader({super.key});

  @override
  Widget build(BuildContext context) => Container(color: context.m24.colors.surfaceAlt, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: <Widget>[
        Expanded(flex: 4, child: Text(context.l10n.t('homeTableParameter'), style: context.m24.text.label)),
        Expanded(flex: 3, child: Text(context.l10n.t('analysisValueColumn'), style: context.m24.text.label)),
        Expanded(flex: 3, child: Text(context.l10n.t('analysisOutcomeColumn'), style: context.m24.text.label)),
        Expanded(flex: 3, child: Text(context.l10n.t('homeTableVerification'), style: context.m24.text.label)),
        SizedBox(width: 88, child: Text(context.l10n.t('analysisActionsColumn'), style: context.m24.text.label)),
      ]));
}

class AnalysisValueRow extends StatelessWidget {
  const AnalysisValueRow({super.key, required this.observation, this.biomarker, required this.desktop, required this.busy, this.showDivider = false, this.onApprove, this.onDiscard});

  final Observation observation;
  final Biomarker? biomarker;
  final bool desktop;
  final bool busy;
  final bool showDivider;
  final VoidCallback? onApprove;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final String name = biomarker?.name(Localizations.localeOf(context).languageCode) ?? (observation.displayName.isEmpty ? observation.code : observation.displayName);
    final TextStyle? rowStyle = observation.isDiscarded ? context.m24.text.bodySmall.copyWith(decoration: TextDecoration.lineThrough, color: context.m24.colors.inkMuted) : null;
    final Widget actions = busy
        ? const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
        : Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            if (onApprove != null) M24IconButton(key: Key('approve-${observation.id}'), icon: M24Icons.confirm, tooltip: context.l10n.t('analysisApproveAction'), onPressed: onApprove),
            if (onDiscard != null) M24IconButton(key: Key('discard-${observation.id}'), icon: M24Icons.discard, tooltip: context.l10n.t('analysisDiscardAction'), onPressed: onDiscard),
          ]);
    return DefaultTextStyle.merge(style: rowStyle, child: Container(
      decoration: BoxDecoration(color: observation.needsReview && observation.isPending ? context.m24.colors.warningTint : context.m24.colors.surface, border: showDivider ? Border(bottom: BorderSide(color: context.m24.colors.divider)) : null),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: desktop
          ? Row(children: <Widget>[
              Expanded(flex: 4, child: Text(name, style: rowStyle ?? context.m24.text.title, overflow: TextOverflow.ellipsis)),
              Expanded(flex: 3, child: Text(observation.displayValue(), style: rowStyle ?? context.m24.text.bodySmall)),
              Expanded(flex: 3, child: ObservationFlagLabel(flag: observation.flag)),
              Expanded(flex: 3, child: ObservationReviewPill(observation: observation)),
              SizedBox(width: 88, child: Align(alignment: Alignment.centerRight, child: actions)),
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(name, style: rowStyle ?? context.m24.text.title, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(observation.displayValue(), style: rowStyle ?? context.m24.text.bodySmall),
                const SizedBox(height: 5),
                ObservationFlagLabel(flag: observation.flag, short: true),
                const SizedBox(height: 8),
                ObservationReviewPill(observation: observation),
              ])),
              actions,
            ]),
    ));
  }
}

class ObservationReviewPill extends StatelessWidget {
  const ObservationReviewPill({super.key, required this.observation});
  final Observation observation;

  @override
  Widget build(BuildContext context) {
    final (String, M24StatusPillVariant, String?) state = switch (observation.reviewStatus) {
      ObservationReviewStatus.confirmed => (context.l10n.t('analysisReviewConfirmed'), M24StatusPillVariant.success, context.l10n.t(observation.confirmedBy == null ? 'analysisConfirmedByEngine' : 'analysisConfirmedByYou')),
      ObservationReviewStatus.discarded => (context.l10n.t('analysisReviewDiscarded'), M24StatusPillVariant.neutral, null),
      ObservationReviewStatus.pending when observation.needsReview => (context.l10n.t('analysisReviewNeeded'), M24StatusPillVariant.warning, null),
      ObservationReviewStatus.pending => (context.l10n.t('analysisReviewPending'), M24StatusPillVariant.neutral, null),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      M24StatusPill(label: state.$1, variant: state.$2, strikethrough: observation.isDiscarded),
      if (state.$3 != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(state.$3!, style: context.m24.text.caption)),
    ]);
  }
}

class ObservationFlagLabel extends StatelessWidget {
  const ObservationFlagLabel({super.key, required this.flag, this.short = false});
  final ObservationFlag flag;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (flag) {
      ObservationFlag.within => context.m24.colors.success,
      ObservationFlag.criticalLow || ObservationFlag.criticalHigh => context.m24.colors.danger,
      ObservationFlag.below || ObservationFlag.above => context.m24.colors.warning,
      ObservationFlag.unknown => context.m24.colors.neutral,
    };
    final String key = short ? 'analysisFlagShort_${flag.value}' : 'analysisFlag_${flag.value}';
    return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 7),
      Flexible(child: Text(context.l10n.t(key), style: context.m24.text.bodySmall.copyWith(color: color), overflow: TextOverflow.ellipsis)),
    ]);
  }
}

/// Retained for detailed range layouts that consume this public component.
class ValueCell extends StatelessWidget {
  const ValueCell({super.key, required this.label, required this.value, this.detail, this.flag});
  final String label, value;
  final String? detail;
  final ObservationFlag? flag;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(label, style: context.m24.text.label), Text(value, style: context.m24.text.title), if (detail != null) Text(detail!, style: context.m24.text.caption), if (flag != null) M24StatusPill(label: context.l10n.t('analysisFlag_${flag!.value}'), variant: flag == ObservationFlag.within ? M24StatusPillVariant.success : M24StatusPillVariant.warning)]);
}