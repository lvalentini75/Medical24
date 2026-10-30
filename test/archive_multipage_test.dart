import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:medical24/core/models/medical_document.dart';
import 'package:medical24/core/theme/app_theme.dart';
import 'package:medical24/features/archive/data/archive_repository.dart';
import 'package:medical24/features/archive/providers/archive_providers.dart';
import 'package:medical24/features/archive/widgets/add_document_sheet.dart';
import 'package:medical24/features/archive/widgets/duplicate_notice_dialog.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Repository used only by the tests: it records the calls instead of
/// touching Supabase. The app itself never uses a mock.
class FakeArchiveRepository extends ArchiveRepository {
  const FakeArchiveRepository(this.state);

  final FakeArchiveState state;

  @override
  Future<DocumentUsage> documentUsage() async => state.usage;

  @override
  Future<MedicalDocument> createMultiPageDocument({
    required List<Uint8List> pages,
    String? subjectId,
    DocumentSource source = DocumentSource.camera,
    String title = '',
    DocumentCategory category = DocumentCategory.other,
    DateTime? documentDate,
    List<String> tags = const <String>[],
    String? doctorName,
    String? facilityName,
    String? episode,
    String? notes,
    void Function(int done, int total)? onProgress,
  }) async {
    state.uploadedPageCounts.add(pages.length);
    return testDocument('multi-1', title, pageCount: pages.length);
  }

  @override
  Future<DocumentPage2> list({
    String? subjectId,
    DocumentCategory? category,
    int? year,
    DocumentStatus? status,
    String? search,
    ArchiveSort sort = ArchiveSort.dateDesc,
    ArchiveCursor? cursor,
    int limit = 30,
  }) async =>
      DocumentPage2(items: state.documents);

  @override
  Future<List<int>> availableYears({String? subjectId}) async => const <int>[];

  @override
  Future<MedicalDocument?> fetchById(String documentId) async =>
      state.documents.where((MedicalDocument d) => d.id == documentId).firstOrNull;

  @override
  Future<MedicalDocument> dismissDuplicate(String documentId) async {
    state.dismissed.add(documentId);
    return testDocument(documentId, 'Dismissed');
  }

  @override
  Future<String> openOriginal(String newId) async {
    state.discarded.add(newId);
    return 'original-1';
  }

  @override
  Future<XFile> shareFile(String documentId) async {
    state.shared.add(documentId);
    return XFile.fromData(Uint8List.fromList(<int>[1, 2, 3]),
        name: 'original.pdf', mimeType: 'application/pdf');
  }
}

class FakeArchiveState {
  FakeArchiveState({
    this.usage = const DocumentUsage(used: 3, max: 30),
    List<MedicalDocument>? documents,
  }) : documents = documents ?? <MedicalDocument>[];

  final DocumentUsage usage;
  final List<MedicalDocument> documents;
  final List<int> uploadedPageCounts = <int>[];
  final List<String> dismissed = <String>[];
  final List<String> discarded = <String>[];
  final List<String> shared = <String>[];
}

MedicalDocument testDocument(
  String id,
  String title, {
  int pageCount = 1,
  String? duplicateOf,
}) =>
    MedicalDocument(
      id: id,
      ownerId: '00000000-0000-0000-0000-000000000001',
      subjectId: '00000000-0000-0000-0000-000000000001',
      storagePath: 'subjects/example/documents/$id',
      title: title,
      category: DocumentCategory.reports,
      status: DocumentStatus.uploaded,
      pageCount: pageCount,
      duplicateOf: duplicateOf,
      documentDate: DateTime(2026, 3, 4),
    );

/// A real 40x60 JPEG, so the preview can decode it.
Uint8List shot(int seed) {
  final img.Image image = img.Image(width: 40, height: 60);
  img.fill(image, color: img.ColorRgb8(seed * 40, 120, 200));
  return Uint8List.fromList(img.encodeJpg(image));
}

Widget app(Widget child, {List<Object> overrides = const <Object>[]}) =>
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        theme: lightTheme,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    );

void main() {
  testWidgets('multi-page flow: three shots, reorder, delete one page',
      (WidgetTester tester) async {
    final FakeArchiveState state = FakeArchiveState();
    final List<Uint8List> shots = <Uint8List>[shot(1), shot(2), shot(3)];
    await tester.pumpWidget(app(
      Scaffold(body: AddDocumentSheet(initialPages: shots)),
      overrides: <Object>[
        archiveRepositoryProvider
            .overrideWithValue(FakeArchiveRepository(state)),
      ],
    ));
    await tester.pumpAndSettle();

    final _AddDocumentSheetHandle handle = _AddDocumentSheetHandle(tester);
    expect(find.text('3 pages'), findsOneWidget);
    expect(find.byIcon(Icons.crop), findsNWidgets(3));
    expect(handle.pageBytes.first, shots.first);

    // Reorder: move the first page to the end.
    handle.reorder(0, 3);
    await tester.pumpAndSettle();
    expect(handle.pageBytes.last, shots.first);

    // Delete one page.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('2 pages'), findsOneWidget);
    expect(handle.pageBytes.length, 2);
  });

  testWidgets('usage counter reads document_usage()',
      (WidgetTester tester) async {
    final FakeArchiveState state = FakeArchiveState(
        usage: const DocumentUsage(used: 7, max: 30));
    await tester.pumpWidget(app(
      const Scaffold(body: AddDocumentSheet()),
      overrides: <Object>[
        archiveRepositoryProvider
            .overrideWithValue(FakeArchiveRepository(state)),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('7 of 30 documents'), findsWidgets);
  });

  testWidgets('limit reached disables upload and points to Settings',
      (WidgetTester tester) async {
    final FakeArchiveState state = FakeArchiveState(
        usage: const DocumentUsage(used: 30, max: 30));
    await tester.pumpWidget(app(
      const Scaffold(body: AddDocumentSheet()),
      overrides: <Object>[
        archiveRepositoryProvider
            .overrideWithValue(FakeArchiveRepository(state)),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('You have reached your plan limit'), findsOneWidget);
    expect(find.text('Go to Settings'), findsOneWidget);
    final FilledButton upload = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Upload'));
    expect(upload.onPressed, isNull);
  });

  testWidgets('duplicate notice: "keep both" dismisses the badge',
      (WidgetTester tester) async {
    final MedicalDocument copy =
        testDocument('copy-1', 'Copy', duplicateOf: 'original-1');
    final FakeArchiveState state =
        FakeArchiveState(documents: <MedicalDocument>[copy]);
    late BuildContext hostContext;
    await tester.pumpWidget(app(
      Consumer(builder: (BuildContext context, WidgetRef ref, _) {
        hostContext = context;
        return const Scaffold(body: SizedBox.expand());
      }),
      overrides: <Object>[
        archiveRepositoryProvider
            .overrideWithValue(FakeArchiveRepository(state)),
      ],
    ));
    await tester.pumpAndSettle();

    final ProviderContainer container =
        ProviderScope.containerOf(hostContext, listen: false);
    final Future<String?> result = showDialog<String>(
      context: hostContext,
      barrierDismissible: false,
      builder: (_) => DuplicateNoticeDialog(document: copy),
    );
    await tester.pumpAndSettle();
    expect(find.text('This may already be in your archive'), findsOneWidget);

    await tester.tap(find.text('Keep both'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(state.dismissed, <String>['copy-1']);
    expect(container.read(archiveRepositoryProvider), isA<FakeArchiveRepository>());
  });

  testWidgets('duplicate notice: "open original" discards the new copy',
      (WidgetTester tester) async {
    final MedicalDocument copy =
        testDocument('copy-2', 'Copy', duplicateOf: 'original-1');
    final FakeArchiveState state =
        FakeArchiveState(documents: <MedicalDocument>[copy]);
    late BuildContext hostContext;
    await tester.pumpWidget(app(
      Builder(builder: (BuildContext context) {
        hostContext = context;
        return const Scaffold(body: SizedBox.expand());
      }),
      overrides: <Object>[
        archiveRepositoryProvider
            .overrideWithValue(FakeArchiveRepository(state)),
      ],
    ));
    await tester.pumpAndSettle();

    final Future<String?> result = showDialog<String>(
      context: hostContext,
      barrierDismissible: false,
      builder: (_) => DuplicateNoticeDialog(document: copy),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open original'));
    await tester.pumpAndSettle();

    expect(await result, 'original-1');
    expect(state.discarded, <String>['copy-2']);
  });
}

/// Drives the private multi-page state of [AddDocumentSheet] through its
/// public widgets: pages are added by tapping the reorderable list that the
/// sheet rebuilds, so the test stays on the widget surface.
class _AddDocumentSheetHandle {
  _AddDocumentSheetHandle(this.tester);

  final WidgetTester tester;

  ReorderableListView get _list =>
      tester.widget<ReorderableListView>(find.byType(ReorderableListView).first);

  List<Uint8List> get pageBytes => find
      .byType(Image)
      .evaluate()
      .map((Element e) => (e.widget as Image).image)
      .whereType<MemoryImage>()
      .map((MemoryImage image) => image.bytes)
      .toList(growable: false);

  void reorder(int oldIndex, int newIndex) {
    final void Function(int, int)? onReorder = _list.onReorder;
    if (onReorder != null) onReorder(oldIndex, newIndex);
  }
}
