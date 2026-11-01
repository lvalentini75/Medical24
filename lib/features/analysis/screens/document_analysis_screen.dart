import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medical24/core/models/biomarker.dart';
import 'package:medical24/core/models/medical_document.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/core/theme/app_theme.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/analysis/providers/analysis_providers.dart';
import 'package:medical24/features/analysis/widgets/analysis_values_table.dart';
import 'package:medical24/features/analysis/widgets/document_analysis_panel.dart';
import 'package:medical24/features/archive/providers/archive_providers.dart';
import 'package:medical24/features/archive/widgets/document_detail_panel.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Full-width report reading and verification workspace.
class DocumentAnalysisScreen extends ConsumerWidget {
  const DocumentAnalysisScreen({super.key, required this.documentId, this.reviewOnly = false});

  final String documentId;
  final bool reviewOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MedicalDocument?> documentValue = ref.watch(archiveDocumentProvider(documentId));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.t(reviewOnly ? 'analysisReviewTitle' : 'analysisTitle'))),
      body: documentValue.when(
        loading: () => const AppLoadingView(),
        error: (_, __) => AppErrorView(message: context.l10n.t('commonErrorTitle'), onRetry: () => ref.invalidate(archiveDocumentProvider(documentId))),
        data: (MedicalDocument? document) => document == null
            ? AppEmptyView(body: context.l10n.t('archiveDocumentMissing'))
            : DocumentAnalysisWorkspace(document: document, reviewOnly: reviewOnly),
      ),
    );
  }
}

/// Uses a side-by-side page viewer at desktop widths and one column elsewhere.
class DocumentAnalysisWorkspace extends ConsumerWidget {
  const DocumentAnalysisWorkspace({super.key, required this.document, required this.reviewOnly});

  final MedicalDocument document;
  final bool reviewOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double width = MediaQuery.sizeOf(context).width;
    final Widget analysis = AnalysisWorkspaceContent(document: document, reviewOnly: reviewOnly);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(width < 600 ? 12 : 20),
        child: Column(children: <Widget>[
          const ClinicalDisclaimer(),
          const SizedBox(height: 12),
          Expanded(
            child: width >= AppBreakpoints.desktop && reviewOnly
                ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                    Expanded(flex: 4, child: Card(child: Padding(padding: const EdgeInsets.all(12), child: DocumentViewer(document: document)))),
                    const SizedBox(width: 16),
                    Expanded(flex: 6, child: analysis),
                  ])
                : analysis,
          ),
        ]),
      ),
    );
  }
}

/// Resolves values and catalog only through the providers created by P02-A.
class AnalysisWorkspaceContent extends ConsumerWidget {
  const AnalysisWorkspaceContent({super.key, required this.document, required this.reviewOnly});

  final MedicalDocument document;
  final bool reviewOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!reviewOnly) {
      return SingleChildScrollView(child: DocumentAnalysisPanel(document: document));
    }
    final AsyncValue<List<Observation>> values = ref.watch(documentAllObservationsStreamProvider(document.id));
    final AsyncValue<Map<String, Biomarker>> catalog = ref.watch(biomarkerByCodeProvider);
    return values.when(
      loading: () => const AppLoadingView(),
      error: (_, __) => AppErrorView(message: context.l10n.t('commonErrorTitle')),
      data: (List<Observation> observations) => catalog.when(
        loading: () => const AppLoadingView(),
        error: (_, __) => AppErrorView(message: context.l10n.t('commonErrorTitle')),
        data: (Map<String, Biomarker> biomarkers) => ListView(children: <Widget>[
          if (!observations.any((Observation value) => value.isPending))
            AppEmptyView(icon: Icons.check_circle_outline, body: context.l10n.t('analysisReviewComplete')),
          AnalysisValuesTable(observations: observations, catalog: biomarkers),
        ]),
      ),
    );
  }
}