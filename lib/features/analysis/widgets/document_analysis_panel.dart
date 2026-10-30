import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/core/models/biomarker.dart';
import 'package:medical24/core/models/medical_document.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/analysis/data/analysis_repository.dart';
import 'package:medical24/features/analysis/providers/analysis_providers.dart';
import 'package:medical24/features/analysis/widgets/analysis_status_badge.dart';
import 'package:medical24/features/analysis/widgets/analysis_values_table.dart';
import 'package:medical24/features/analysis/widgets/observation_review.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/feedback.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';

/// Analysis state and values embedded in a document detail panel.
class DocumentAnalysisPanel extends ConsumerStatefulWidget {
  const DocumentAnalysisPanel({super.key, required this.document, this.compact = false});

  final MedicalDocument document;
  final bool compact;

  @override
  ConsumerState<DocumentAnalysisPanel> createState() => _DocumentAnalysisPanelState();
}

class _DocumentAnalysisPanelState extends ConsumerState<DocumentAnalysisPanel> {
  bool _autoStartAttempted = false;

  Future<void> _start() async => ref.read(analysisControllerProvider.notifier).start(widget.document.id);

  void _autoStart(Extraction? extraction, AnalysisUsage? usage) {
    if (_autoStartAttempted || extraction != null || usage == null || widget.document.status != DocumentStatus.uploaded) return;
    _autoStartAttempted = true;
    if (!usage.isLimitReached) WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Extraction?> initial = ref.watch(documentExtractionProvider(widget.document.id));
    final AsyncValue<AnalysisUsage> usage = ref.watch(analysisUsageProvider);
    return initial.when(
      loading: () => const AppLoadingView(),
      error: (Object error, StackTrace _) => AppErrorView(
        message: AppFailure.from(error, where: 'analysis.panel').localized(Localizations.localeOf(context).languageCode),
        onRetry: () => ref.invalidate(documentExtractionProvider(widget.document.id)),
      ),
      data: (Extraction? extraction) {
        _autoStart(extraction, usage.hasValue ? usage.requireValue : null);
        if (extraction == null) return AnalysisNotStarted(documentId: widget.document.id, usage: usage, onStart: _start);
        return ref.watch(extractionStreamProvider(extraction.id)).when(
          loading: () => AnalysisPanelContent(document: widget.document, extraction: extraction, usage: usage, compact: widget.compact),
          error: (_, __) => AnalysisPanelContent(document: widget.document, extraction: extraction, usage: usage, compact: widget.compact),
          data: (Extraction? realtime) => AnalysisPanelContent(document: widget.document, extraction: realtime ?? extraction, usage: usage, compact: widget.compact),
        );
      },
    );
  }
}

/// Empty/limit state before a document has an extraction row.
class AnalysisNotStarted extends StatelessWidget {
  const AnalysisNotStarted({super.key, required this.documentId, required this.usage, required this.onStart});

  final String documentId;
  final AsyncValue<AnalysisUsage> usage;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final AnalysisUsage? value = usage.hasValue ? usage.requireValue : null;
    final bool limited = value?.isLimitReached ?? false;
    return Card(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Text(limited ? context.l10n.t('analysisLimitReachedTitle') : context.l10n.t('analysisNotStartedTitle'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(limited ? context.l10n.t('analysisLimitReachedBody', args: <String, String>{'max': '${value?.max ?? 0}'}) : context.l10n.t('analysisNotStartedBody')),
        const SizedBox(height: 16),
        if (limited)
          OutlinedButton(onPressed: () => context.push(AppRoutes.settings), child: Text(context.l10n.t('archiveOpenSettings')))
        else
          FilledButton(onPressed: usage.isLoading ? null : onStart, child: Text(context.l10n.t('analysisStartAction'))),
      ]),
    ));
  }
}

/// The four real extraction states: running, review, complete and failed.
class AnalysisPanelContent extends ConsumerWidget {
  const AnalysisPanelContent({super.key, required this.document, required this.extraction, required this.usage, required this.compact});

  final MedicalDocument document;
  final Extraction extraction;
  final AsyncValue<AnalysisUsage> usage;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<void> action = ref.watch(analysisControllerProvider);
    if (extraction.isRunning) {
      return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        AnalysisStatusBadge(extraction: extraction),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: extraction.progress, semanticsLabel: context.l10n.t('analysisReadingProgress')),
        const SizedBox(height: 10),
        Text(context.l10n.t('analysisUsuallyUnderMinute')),
      ])));
    }
    if (extraction.status == ExtractionStatus.failed) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[M24Banner(title: context.l10n.t('analysisStatus_failed'), subtitle: context.l10n.t(_failureMessageKey(extraction.failureReason)), variant: M24BannerVariant.warning), const SizedBox(height: 12), M24Button(label: context.l10n.t('analysisRetryAction'), icon: M24Icons.review, onPressed: action.isLoading ? null : () => ref.read(analysisControllerProvider.notifier).retry(document.id))]);
    }
    if (extraction.status == ExtractionStatus.done && extraction.valuesTotal == 0) {
      final bool skipped = extraction.failureReason == 'skipped_not_lab';
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[M24Banner(title: context.l10n.t(skipped ? 'analysisStatusSkipped' : 'analysisStatusNoValues'), subtitle: context.l10n.t(skipped ? 'analysisSkippedNotLabBody' : 'analysisNoValuesBody'), variant: M24BannerVariant.info), if (!skipped) ...<Widget>[const SizedBox(height: 8), Text(context.l10n.t('analysisNoValuesAdvice'))], const SizedBox(height: 12), M24Button(label: context.l10n.t(skipped ? 'analysisReadAnywayAction' : 'analysisRetryAction'), onPressed: action.isLoading || (usage.hasValue && usage.requireValue.isLimitReached) ? null : skipped ? () => ref.read(analysisControllerProvider.notifier).run(extraction.id, document.id, force: true) : () => ref.read(analysisControllerProvider.notifier).retry(document.id))]);
    }
    final AsyncValue<List<Observation>> observations = ref.watch(documentObservationsStreamProvider(document.id));
    final AsyncValue<Map<String, Biomarker>> catalog = ref.watch(biomarkerByCodeProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        AnalysisStatusBadge(extraction: extraction),
        const SizedBox(height: 12),
        if (extraction.status == ExtractionStatus.done && extraction.finishedAt != null)
          Text(context.l10n.t('analysisCompletedAt', args: <String, String>{'date': DateFormat.yMMMd(Localizations.localeOf(context).languageCode).add_Hm().format(extraction.finishedAt!.toLocal())})),
        if (usage.hasValue) Text(context.l10n.t('analysisUsageCounter', args: <String, String>{'used': '${usage.requireValue.used}', 'max': '${usage.requireValue.max}'})),
        const SizedBox(height: 16),
        if (extraction.status == ExtractionStatus.needsReview)
          FilledButton(
            onPressed: observations.hasValue && catalog.hasValue ? () {
              final List<Observation> pending = observations.requireValue.where((Observation value) => value.needsReview).toList(growable: false);
              if (MediaQuery.sizeOf(context).width < 600) {
                ObservationReview.showPhone(context, pending, catalog.requireValue);
              } else {
                context.push(AppRoutes.analysisReview(document.id));
              }
            } : null,
            child: Text(context.l10n.t('analysisVerifyAction')),
          )
        else
          FilledButton(
            onPressed: action.isLoading || (usage.hasValue && usage.requireValue.isLimitReached) ? null : () => ref.read(analysisControllerProvider.notifier).start(document.id),
            child: Text(context.l10n.t('analysisUpdateAction')),
          ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => context.push(AppRoutes.analysis(document.id)), child: Text(context.l10n.t('analysisViewAction'))),
      ]))),
      if (!compact) ...<Widget>[
        const SizedBox(height: 12),
        observations.when(
          loading: () => const AppLoadingView(),
          error: (_, __) => AppErrorView(message: context.l10n.t('commonErrorTitle')),
          data: (List<Observation> values) => catalog.when(
            loading: () => const AppLoadingView(),
            error: (_, __) => AppErrorView(message: context.l10n.t('commonErrorTitle')),
            data: (Map<String, Biomarker> biomarkers) => AnalysisValuesTable(observations: values, catalog: biomarkers),
          ),
        ),
      ],
    ]);
  }

  String _failureMessageKey(String? reason) {
    if (reason?.startsWith('api_') ?? false) return 'analysisFailureApi';
    if (reason?.startsWith('storage_') ?? false) return 'analysisFailureStorage';
    if (reason?.startsWith('network_') ?? false) return 'analysisFailureNetwork';
    return switch (reason) {
      'pdf_parse_error' => 'analysisFailurePdfParse',
      'invalid_output' => 'analysisFailureInvalidOutput',
      'missing_api_key' => 'analysisFailureMissingApiKey',
      _ => 'analysisFailedBody',
    };
  }
}