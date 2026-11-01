import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical24/core/models/biomarker.dart';
import 'package:medical24/core/models/medical_document.dart';
import 'package:medical24/core/models/observation.dart';
import 'package:medical24/features/analysis/data/analysis_repository.dart';
import 'package:medical24/features/analysis/providers/analysis_providers.dart';
import 'package:medical24/features/analysis/widgets/analysis_status_badge.dart';
import 'package:medical24/features/analysis/widgets/analysis_values_table.dart';
import 'package:medical24/features/analysis/widgets/document_analysis_panel.dart';
import 'package:medical24/features/analysis/widgets/observation_review.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

const Biomarker _glucose = Biomarker(
  code: '2345-7',
  nameIt: 'Glicemia',
  nameEn: 'Glucose',
  category: 'Metabolism',
  unitCanonical: 'mg/dL',
  status: CatalogStatus.draft,
  boardVersion: 0,
);

Observation _observation({String id = 'observation-test', bool review = false, ObservationReviewStatus reviewStatus = ObservationReviewStatus.pending, String? confirmedBy, ObservationFlag flag = ObservationFlag.above}) => Observation(
      id: id,
      subjectId: 'subject-test',
      code: '2345-7',
      displayName: 'Glucose',
      valueNum: 180,
      unit: 'mg/dL',
      labLow: 70,
      labHigh: 100,
      refLow: 70,
      refHigh: 99,
      effectiveAt: DateTime(2026),
      needsReview: review,
      confidence: review ? 0.54 : null,
      reviewStatus: reviewStatus,
      confirmedAt: reviewStatus == ObservationReviewStatus.pending ? null : DateTime(2026),
      confirmedBy: confirmedBy,
      flag: flag,
    );

MedicalDocument _document() => const MedicalDocument(
      id: 'document-test',
      ownerId: 'owner-test',
      subjectId: 'subject-test',
      storagePath: 'test/document',
      title: 'Blood test',
      status: DocumentStatus.uploaded,
    );

Widget _localized(Widget child) => ProviderScope(child: MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ));

const List<Size> _breakpoints = <Size>[
  Size(390, 844),
  Size(834, 1194),
  Size(1920, 1080),
];

class AnalysisPanelTestApp extends StatelessWidget {
  const AnalysisPanelTestApp({super.key, required this.extraction});

  final Extraction extraction;

  @override
  Widget build(BuildContext context) => ProviderScope(
        overrides: [
          documentObservationsStreamProvider('document-test').overrideWith(
            (Ref ref) => Stream<List<Observation>>.value(<Observation>[_observation()]),
          ),
          biomarkerByCodeProvider.overrideWith(
            (Ref ref) async => <String, Biomarker>{_glucose.code: _glucose},
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalysisPanelContent(
                document: _document(),
                extraction: extraction,
                usage: const AsyncValue<AnalysisUsage>.data(AnalysisUsage(used: 1, max: 30)),
                compact: true,
              ),
            ),
          ),
        ),
      );
}

void main() {
  testWidgets('values table marks a value above the laboratory range', (WidgetTester tester) async {
    await tester.pumpWidget(_localized(AnalysisValuesTable(observations: <Observation>[_observation()], catalog: <String, Biomarker>{_glucose.code: _glucose})));
    expect(find.text('Above the range'), findsOneWidget);
    expect(find.text('180 mg/dL'), findsOneWidget);
  });

  testWidgets('values table renders confirmed, review, and pending pills', (WidgetTester tester) async {
    await tester.pumpWidget(_localized(AnalysisValuesTable(
      observations: <Observation>[
        _observation(id: 'confirmed', reviewStatus: ObservationReviewStatus.confirmed),
        _observation(id: 'review', review: true),
        _observation(id: 'pending'),
      ],
      catalog: <String, Biomarker>{_glucose.code: _glucose},
    )));
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('by the engine'), findsOneWidget);
    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('approve acts on one pending row', (WidgetTester tester) async {
    Observation? approved;
    await tester.pumpWidget(_localized(AnalysisValuesTable(
      observations: <Observation>[_observation()],
      catalog: <String, Biomarker>{_glucose.code: _glucose},
      onApprove: (Observation value) async { approved = value; return true; },
    )));
    await tester.tap(find.byKey(const Key('approve-observation-test')));
    await tester.pump();
    expect(approved?.id, 'observation-test');
  });

  testWidgets('discard asks for confirmation before acting', (WidgetTester tester) async {
    bool discarded = false;
    await tester.pumpWidget(_localized(AnalysisValuesTable(
      observations: <Observation>[_observation(reviewStatus: ObservationReviewStatus.confirmed)],
      catalog: <String, Biomarker>{_glucose.code: _glucose},
      onDiscard: (_) async { discarded = true; return true; },
    )));
    await tester.tap(find.byKey(const Key('discard-observation-test')));
    await tester.pumpAndSettle();
    expect(find.text('Discard this value?'), findsOneWidget);
    expect(discarded, isFalse);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(discarded, isTrue);
  });

  testWidgets('confirm all displays progress and final result', (WidgetTester tester) async {
    final Completer<bool> first = Completer<bool>();
    int calls = 0;
    await tester.pumpWidget(_localized(AnalysisValuesTable(
      observations: <Observation>[_observation(id: 'one'), _observation(id: 'two', review: true)],
      catalog: <String, Biomarker>{_glucose.code: _glucose},
      onApprove: (_) { calls++; return calls == 1 ? first.future : Future<bool>.value(true); },
    )));
    await tester.tap(find.byKey(const Key('analysis-confirm-all')));
    await tester.pump();
    expect(find.byKey(const Key('analysis-confirm-all-progress')), findsOneWidget);
    expect(find.text('0 of 2 values processed'), findsOneWidget);
    first.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('2 confirmed, 0 errors'), findsOneWidget);
  });

  testWidgets('analysis status badge renders the list state', (WidgetTester tester) async {
    const Extraction extraction = Extraction(id: 'extraction-test', documentId: 'document-test', subjectId: 'subject-test', status: ExtractionStatus.needsReview, valuesToReview: 2);
    await tester.pumpWidget(_localized(const AnalysisStatusBadge(extraction: extraction)));
    expect(find.text('Needs review: 2'), findsOneWidget);
  });

  testWidgets('values found is complete at all three breakpoints', (WidgetTester tester) async {
    const Extraction extraction = Extraction(id: 'values-found', documentId: 'document-test', subjectId: 'subject-test', status: ExtractionStatus.done, valuesTotal: 1, valuesSaved: 1);
    for (final Size size in _breakpoints) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const AnalysisPanelTestApp(extraction: extraction));
      await tester.pump();
      expect(find.text('Reading completed'), findsOneWidget);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('skipped document offers read anyway at all three breakpoints', (WidgetTester tester) async {
    const Extraction extraction = Extraction(id: 'skipped', documentId: 'document-test', subjectId: 'subject-test', status: ExtractionStatus.done, failureReason: 'skipped_not_lab');
    for (final Size size in _breakpoints) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const AnalysisPanelTestApp(extraction: extraction));
      await tester.pump();
      expect(find.text('This does not appear to be a laboratory report: there are no values to extract'), findsOneWidget);
    expect(find.text('Read anyway'), findsOneWidget);
      expect(find.text('Reading completed'), findsNothing);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('zero values offers retry at all three breakpoints', (WidgetTester tester) async {
    const Extraction extraction = Extraction(id: 'no-values', documentId: 'document-test', subjectId: 'subject-test', status: ExtractionStatus.done);
    for (final Size size in _breakpoints) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const AnalysisPanelTestApp(extraction: extraction));
      await tester.pump();
      expect(find.text('No values were recognised on these pages'), findsOneWidget);
      expect(find.text('Try again with sharp, straight photos that show all the text.'), findsOneWidget);
      expect(find.text('Try reading again'), findsOneWidget);
      expect(find.text('Reading completed'), findsNothing);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('review presents approve, correct and discard choices', (WidgetTester tester) async {
    await tester.pumpWidget(_localized(ObservationReview(observations: <Observation>[_observation(review: true)], catalog: <String, Biomarker>{_glucose.code: _glucose})));
    expect(find.text('Confirm the value'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
  });
}