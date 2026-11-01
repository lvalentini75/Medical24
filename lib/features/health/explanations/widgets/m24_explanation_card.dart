import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/features/health/explanations/data/explanation_repository.dart';
import 'package:medical24/features/health/explanations/providers/explanation_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Connects a report header action to its explanation card.
class M24ExplanationController extends ChangeNotifier {
  VoidCallback? _activate;
  bool _hasText = false;

  bool get hasText => _hasText;
  void activate() => _activate?.call();

  void _attach(VoidCallback activate) => _activate = activate;
  void _detach(VoidCallback activate) { if (_activate == activate) _activate = null; }
  void _setHasText(bool value) { if (_hasText == value) return; _hasText = value; notifyListeners(); }
}

/// Full-width report explanation action used in analysis and archive headers.
class ReportExplanationButton extends StatelessWidget {
  const ReportExplanationButton({super.key, required this.controller, required this.enabled});
  final M24ExplanationController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (BuildContext context, Widget? child) {
      final M24Button button = M24Button(
        key: const Key('report-explanation-cta'),
        label: controller.hasText ? context.l10n.explanationReportCtaReread : context.l10n.explanationReportCta,
        icon: LucideIcons.sparkles,
        size: M24ButtonSize.large,
        variant: controller.hasText ? M24ButtonVariant.accentOutline : M24ButtonVariant.accent,
        onPressed: enabled ? controller.activate : null,
      );
      return enabled ? button : Tooltip(message: context.l10n.explanationReportCtaDisabled, child: button);
    },
  );
}

/// Cached AI explanation shared by document, biomarker, organ, and risk views.
class M24ExplanationCard extends ConsumerStatefulWidget {
  const M24ExplanationCard({super.key, required this.subjectId, required this.targetType, required this.targetId, this.available = true, this.controller});
  final String subjectId;
  final ExplanationTargetType targetType;
  final String targetId;
  final bool available;
  final M24ExplanationController? controller;

  @override
  ConsumerState<M24ExplanationCard> createState() => _M24ExplanationCardState();
}

class _M24ExplanationCardState extends ConsumerState<M24ExplanationCard> {
  ExplanationLevel _level = ExplanationLevel.simple;
  ExplanationResult? _result;
  ExplanationUsage? _usage;
  ExplanationRefusal? _refusal;
  bool _loading = true;
  bool _generating = false;
  bool _error = false;
  bool _retryGeneration = false;
  String? _lang;

  ExplanationRepository get _repository => ref.read(explanationRepositoryProvider);

  @override
  void initState() { super.initState(); widget.controller?._attach(_activate); }

  @override
  void dispose() { widget.controller?._detach(_activate); super.dispose(); }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String lang = _language;
    if (_lang != lang) {
      _lang = lang;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void didUpdateWidget(covariant M24ExplanationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(_activate);
      widget.controller?._attach(_activate);
      widget.controller?._setHasText(_result != null);
    }
    if (oldWidget.subjectId != widget.subjectId || oldWidget.targetType != widget.targetType || oldWidget.targetId != widget.targetId || oldWidget.available != widget.available) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  String get _language => Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'it';
  ExplanationRequest get _request => ExplanationRequest(subjectId: widget.subjectId, targetType: widget.targetType, targetId: widget.targetId, level: _level, lang: _language);

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = false; _retryGeneration = false; _refusal = null; _result = null; });
    try {
      _level = await _repository.readPreferredLevel();
      if (!widget.available) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final List<dynamic> values = await Future.wait<dynamic>(<Future<dynamic>>[_repository.usage(widget.subjectId), _repository.lookup(_request)]);
      if (mounted) {
        setState(() { _usage = values[0] as ExplanationUsage; _result = values[1] as ExplanationResult?; _loading = false; });
        widget.controller?._setHasText(_result != null);
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _generate({bool force = false}) async {
    setState(() { _generating = true; _error = false; _retryGeneration = false; _refusal = null; });
    try {
      final ExplanationResult result = await _repository.generate(_request, force: force);
      final ExplanationUsage usage = await _repository.usage(widget.subjectId);
      if (mounted) { setState(() { _result = result; _usage = usage; }); widget.controller?._setHasText(true); }
    } on ExplanationRefused catch (refused) {
      if (mounted) { setState(() { _result = null; _refusal = refused.reason; }); widget.controller?._setHasText(false); }
    } catch (_) {
      if (mounted) setState(() { _error = true; _retryGeneration = true; });
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _changeLevel(ExplanationLevel level) async {
    if (level == _level) return;
    setState(() { _level = level; _result = null; _refusal = null; _error = false; _generating = true; });
    widget.controller?._setHasText(false);
    await _repository.savePreferredLevel(level);
    try {
      final ExplanationResult? cached = await _repository.lookup(_request);
      if (cached != null) {
        if (mounted) { setState(() => _result = cached); widget.controller?._setHasText(true); }
      } else {
        final ExplanationResult generated = await _repository.generate(_request);
        if (mounted) { setState(() => _result = generated); widget.controller?._setHasText(true); }
      }
    } on ExplanationRefused catch (refused) {
      if (mounted) setState(() => _refusal = refused.reason);
    } catch (_) {
      if (mounted) setState(() { _error = true; _retryGeneration = true; });
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _activate() async {
    await Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic, alignment: .08);
    if (!mounted || _generating) return;
    if (_level == ExplanationLevel.simple && _result != null) return;
    setState(() { _level = ExplanationLevel.simple; _result = null; _refusal = null; _error = false; _generating = true; });
    widget.controller?._setHasText(false);
    await _repository.savePreferredLevel(ExplanationLevel.simple);
    try {
      final ExplanationResult? cached = await _repository.lookup(_request);
      if (cached != null) {
        if (mounted) { setState(() => _result = cached); widget.controller?._setHasText(true); }
      } else {
        final ExplanationResult generated = await _repository.generate(_request);
        final ExplanationUsage usage = await _repository.usage(widget.subjectId);
        if (mounted) { setState(() { _result = generated; _usage = usage; }); widget.controller?._setHasText(true); }
      }
    } on ExplanationRefused catch (refused) {
      if (mounted) setState(() => _refusal = refused.reason);
    } catch (_) {
      if (mounted) setState(() { _error = true; _retryGeneration = true; });
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _confirmRegenerate() async {
    final bool confirmed = await showDialog<bool>(context: context, builder: (BuildContext dialogContext) => AlertDialog(title: Text(context.l10n.explanationRegenerateTitle), content: Text(context.l10n.explanationRegenerateConfirm), actions: <Widget>[M24Button(label: context.l10n.commonCancel, variant: M24ButtonVariant.tertiary, onPressed: () => dialogContext.pop(false)), M24Button(label: context.l10n.explanationRegenerate, variant: M24ButtonVariant.secondary, onPressed: () => dialogContext.pop(true))])) ?? false;
    if (confirmed) await _generate(force: true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(explanationRefreshProvider, (_, __) => WidgetsBinding.instance.addPostFrameCallback((_) => _load()));
    final AppLocalizations l = context.l10n;
    return M24Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Expanded(child: Text(l.explanationTitle, style: context.m24.text.h2)),
        Flexible(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: M24Segmented<ExplanationLevel>(segments: <M24Segment<ExplanationLevel>>[M24Segment<ExplanationLevel>(value: ExplanationLevel.simple, label: l.explanationSimple), M24Segment<ExplanationLevel>(value: ExplanationLevel.clinical, label: l.explanationClinical)], selected: _level, onChanged: _generating || !widget.available ? null : _changeLevel))),
        if (_result != null) PopupMenuButton<String>(tooltip: l.explanationMore, icon: const Icon(LucideIcons.ellipsisVertical), onSelected: (_) => _confirmRegenerate(), itemBuilder: (_) => <PopupMenuEntry<String>>[PopupMenuItem<String>(value: 'regenerate', child: Text(l.explanationRegenerate))]),
      ]),
      const SizedBox(height: 10),
      if (!widget.available) Text(l.explanationConfirmValues, style: context.m24.text.bodySmall)
      else if (_loading || _generating) ExplanationLoadingState(label: l.explanationWriting)
      else if (_refusal == ExplanationRefusal.filter) M24Banner(title: l.explanationUnavailable, subtitle: l.explanationUnavailableAdvice, variant: M24BannerVariant.primary)
      else if (_refusal == ExplanationRefusal.limit) M24Banner(title: l.explanationLimitReached, subtitle: l.explanationLimitTomorrow, variant: M24BannerVariant.primary)
      else if (_error) Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[M24Banner(title: l.explanationError, subtitle: l.explanationErrorAdvice, variant: M24BannerVariant.warning), const SizedBox(height: 10), Align(alignment: Alignment.centerLeft, child: M24Button(label: l.commonRetry, variant: M24ButtonVariant.secondary, onPressed: _retryGeneration ? _generate : _load))])
      else if (_result != null) ExplanationTextState(result: _result!)
      else ExplanationInitialState(targetType: widget.targetType, remaining: _usage?.remaining ?? 0, onGenerate: _generate),
    ]));
  }
}

class ExplanationInitialState extends StatelessWidget {
  const ExplanationInitialState({super.key, required this.targetType, required this.remaining, required this.onGenerate});
  final ExplanationTargetType targetType;
  final int remaining;
  final VoidCallback onGenerate;
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final String label = switch (targetType) { ExplanationTargetType.biomarker => l.explanationExplainValue, ExplanationTargetType.organ => l.explanationExplainOrgan, ExplanationTargetType.risk => l.explanationExplainRisk, ExplanationTargetType.document => l.explanationExplainDocument };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[M24Button(label: label, variant: M24ButtonVariant.secondary, onPressed: onGenerate), const SizedBox(height: 6), Text(l.explanationUsageNote(remaining), style: context.m24.text.caption)]);
  }
}

class ExplanationLoadingState extends StatelessWidget {
  const ExplanationLoadingState({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(label, style: context.m24.text.bodySmall), const SizedBox(height: 12), for (final double width in <double>[1, .92, .78]) Padding(padding: const EdgeInsets.only(bottom: 8), child: FractionallySizedBox(widthFactor: width, child: Container(height: 14, decoration: BoxDecoration(color: context.m24.colors.surfaceAlt, borderRadius: BorderRadius.circular(8)))))]);
}

class ExplanationTextState extends StatelessWidget {
  const ExplanationTextState({super.key, required this.result});
  final ExplanationResult result;
  @override
  Widget build(BuildContext context) {
    final String date = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(result.generatedAt.toLocal());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(context.l10n.explanationGeneratedMeta(result.model, date), style: context.m24.text.caption),
      if (result.cached) Padding(padding: const EdgeInsets.only(top: 4), child: M24StatusPill(label: context.l10n.explanationUpdatedAt(date), variant: M24StatusPillVariant.neutral)),
      const SizedBox(height: 12), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: Text(result.text, style: context.m24.text.body)),
      const SizedBox(height: 14), M24Disclaimer(phoneText: context.l10n.explanationRequiredClosing, desktopText: context.l10n.explanationRequiredClosing),
    ]);
  }
}