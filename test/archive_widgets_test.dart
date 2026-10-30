import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical24/core/models/medical_document.dart';
import 'package:medical24/core/theme/app_theme.dart';
import 'package:medical24/features/archive/providers/archive_providers.dart';
import 'package:medical24/features/archive/widgets/add_document_sheet.dart';
import 'package:medical24/features/archive/widgets/archive_document_list.dart';
import 'package:medical24/features/archive/widgets/document_detail_panel.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

Widget _app(Widget child) => MaterialApp(
      theme: lightTheme,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

MedicalDocument _document(String id, String title) => MedicalDocument(
      id: id,
      ownerId: '00000000-0000-0000-0000-000000000001',
      subjectId: '00000000-0000-0000-0000-000000000001',
      storagePath: 'subjects/example/documents/$id',
      title: title,
      category: DocumentCategory.reports,
      status: DocumentStatus.analyzed,
      documentDate: DateTime(2024, 1, 2),
    );

void main() {
  testWidgets('empty archive list renders without documents', (WidgetTester tester) async {
    await tester.pumpWidget(_app(Material(child: ArchiveDocumentList(documents: const <MedicalDocument>[], onOpen: (_) {}))));
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveDocumentRow), findsNothing);
  });

  testWidgets('archive list renders fixtures at three breakpoints', (WidgetTester tester) async {
    final List<MedicalDocument> documents = <MedicalDocument>[
      _document('doc-1', 'Report one'),
      _document('doc-2', 'Report two'),
      _document('doc-3', 'Report three'),
    ];
    for (final Size size in <Size>[const Size(390, 844), const Size(834, 1194), const Size(1920, 1080)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(Material(child: ArchiveDocumentList(documents: documents, onOpen: (_) {}))));
      await tester.pumpAndSettle();
      expect(find.text('Report one'), findsOneWidget);
      expect(find.text('Report two'), findsOneWidget);
      expect(find.text('Report three'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('upload sheet opens', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(child: _app(const Scaffold(body: SizedBox()))));
    await tester.runAsync(() => AddDocumentSheet.show(tester.element(find.byType(SizedBox))));
    await tester.pumpAndSettle();
    expect(find.text('Add document'), findsOneWidget);
  });

  testWidgets('document detail uses the supplied fake repository value', (WidgetTester tester) async {
    final MedicalDocument document = _document('detail-1', 'Detail report');
    await tester.pumpWidget(ProviderScope(
      overrides: [archiveDocumentProvider(document.id).overrideWith((ref) async => document)],
      child: _app(const SizedBox(height: 500, child: DocumentDetailPanel(documentId: 'detail-1'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Detail report'), findsOneWidget);
  });
}