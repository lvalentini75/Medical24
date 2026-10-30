import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/medical_document.dart';
import '../../../core/providers/app_providers.dart';
import '../data/archive_repository.dart';

/// Single instance of the archive repository.
final Provider<ArchiveRepository> archiveRepositoryProvider =
    Provider<ArchiveRepository>((Ref ref) => const ArchiveRepository());

/// Subject whose archive is shown. Until family delegation (P05) it is
/// always the signed-in user; `can_access_subject` guards it anyway.
final Provider<String?> archiveSubjectIdProvider = Provider<String?>((Ref ref) {
  final profile = ref.watch(myProfileProvider);
  return profile.hasValue ? profile.requireValue?.id : null;
});

/// Active filters of the archive list.
class ArchiveFilter {
  const ArchiveFilter({
    this.category,
    this.year,
    this.status,
    this.search,
    this.sort = ArchiveSort.dateDesc,
  });

  final DocumentCategory? category;
  final int? year;
  final DocumentStatus? status;
  final String? search;
  final ArchiveSort sort;

  bool get isEmpty =>
      category == null &&
      year == null &&
      status == null &&
      (search == null || search!.trim().isEmpty);

  ArchiveFilter copyWith({
    DocumentCategory? category,
    int? year,
    DocumentStatus? status,
    String? search,
    ArchiveSort? sort,
    bool clearCategory = false,
    bool clearYear = false,
    bool clearStatus = false,
    bool clearSearch = false,
  }) =>
      ArchiveFilter(
        category: clearCategory ? null : (category ?? this.category),
        year: clearYear ? null : (year ?? this.year),
        status: clearStatus ? null : (status ?? this.status),
        search: clearSearch ? null : (search ?? this.search),
        sort: sort ?? this.sort,
      );

  @override
  bool operator ==(Object other) =>
      other is ArchiveFilter &&
      other.category == category &&
      other.year == year &&
      other.status == status &&
      other.search == search &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(category, year, status, search, sort);
}

class ArchiveFilterNotifier extends Notifier<ArchiveFilter> {
  @override
  ArchiveFilter build() => const ArchiveFilter();

  void setCategory(DocumentCategory? value) => state = value == null
      ? state.copyWith(clearCategory: true)
      : state.copyWith(category: value);

  void setYear(int? value) =>
      state = value == null ? state.copyWith(clearYear: true) : state.copyWith(year: value);

  void setStatus(DocumentStatus? value) => state = value == null
      ? state.copyWith(clearStatus: true)
      : state.copyWith(status: value);

  void setSearch(String? value) => state = (value == null || value.trim().isEmpty)
      ? state.copyWith(clearSearch: true)
      : state.copyWith(search: value.trim());

  void setSort(ArchiveSort value) => state = state.copyWith(sort: value);

  void reset() => state = const ArchiveFilter();
}

final NotifierProvider<ArchiveFilterNotifier, ArchiveFilter>
    archiveFilterProvider =
    NotifierProvider<ArchiveFilterNotifier, ArchiveFilter>(
        ArchiveFilterNotifier.new);

/// Paginated archive list. Reloads whenever the filter changes.
class ArchiveListNotifier extends AsyncNotifier<List<MedicalDocument>> {
  ArchiveCursor? _cursor;
  bool _loadingMore = false;

  bool get hasMore => _cursor != null;

  @override
  Future<List<MedicalDocument>> build() async {
    final ArchiveFilter filter = ref.watch(archiveFilterProvider);
    ref.watch(archiveSubjectIdProvider);
    _cursor = null;
    final DocumentPage2 page = await _fetch(filter, null);
    _cursor = page.nextCursor;
    return page.items;
  }

  Future<DocumentPage2> _fetch(ArchiveFilter filter, ArchiveCursor? cursor) =>
      ref.read(archiveRepositoryProvider).list(
            subjectId: ref.read(archiveSubjectIdProvider),
            category: filter.category,
            year: filter.year,
            status: filter.status,
            search: filter.search,
            sort: filter.sort,
            cursor: cursor,
          );

  Future<void> loadMore() async {
    if (_loadingMore || _cursor == null || !state.hasValue) return;
    _loadingMore = true;
    try {
      final DocumentPage2 page =
          await _fetch(ref.read(archiveFilterProvider), _cursor);
      _cursor = page.nextCursor;
      state = AsyncValue<List<MedicalDocument>>.data(
        <MedicalDocument>[...state.requireValue, ...page.items],
      );
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue<List<MedicalDocument>>.loading();
    state = await AsyncValue.guard<List<MedicalDocument>>(() async {
      _cursor = null;
      final DocumentPage2 page =
          await _fetch(ref.read(archiveFilterProvider), null);
      _cursor = page.nextCursor;
      return page.items;
    });
  }

  /// Uploads one picked file and puts it at the top of the list.
  Future<MedicalDocument> upload({
    required Uint8List bytes,
    required String originalName,
    required DocumentSource source,
    String title = '',
    DocumentCategory category = DocumentCategory.other,
    DateTime? documentDate,
    List<String> tags = const <String>[],
  }) async {
    final MedicalDocument document =
        await ref.read(archiveRepositoryProvider).ingestFile(
              bytes: bytes,
              originalName: originalName,
              source: source,
              subjectId: ref.read(archiveSubjectIdProvider),
              title: title,
              category: category,
              documentDate: documentDate,
              tags: tags,
            );
    await refresh();
    ref.invalidate(archiveUsageProvider);
    return document;
  }

  Future<MedicalDocument> updateMetadata(
    String documentId, {
    String? title,
    DocumentCategory? category,
    DateTime? documentDate,
    List<String>? tags,
    String? doctorName,
    String? facilityName,
    String? episode,
    String? notes,
  }) async {
    final MedicalDocument updated =
        await ref.read(archiveRepositoryProvider).updateMetadata(
              documentId,
              title: title,
              category: category,
              documentDate: documentDate,
              tags: tags,
              doctorName: doctorName,
              facilityName: facilityName,
              episode: episode,
              notes: notes,
            );
    if (state.hasValue) {
      state = AsyncValue<List<MedicalDocument>>.data(
        state.requireValue
            .map((MedicalDocument d) => d.id == documentId ? updated : d)
            .toList(growable: false),
      );
    }
    return updated;
  }

  Future<void> softDelete(MedicalDocument document) async {
    await ref.read(archiveRepositoryProvider).softDelete(document);
    if (state.hasValue) {
      state = AsyncValue<List<MedicalDocument>>.data(
        state.requireValue
            .where((MedicalDocument d) => d.id != document.id)
            .toList(growable: false),
      );
    }
  }

  /// Camera / gallery flow: the pages become one document whose original
  /// is the PDF composed on the client.
  Future<MedicalDocument> uploadPages({
    required List<Uint8List> pages,
    DocumentSource source = DocumentSource.camera,
    String title = '',
    DocumentCategory category = DocumentCategory.other,
    DateTime? documentDate,
    List<String> tags = const <String>[],
    String? doctorName,
    String? facilityName,
    String? episode,
    void Function(int done, int total)? onProgress,
  }) async {
    final MedicalDocument document =
        await ref.read(archiveRepositoryProvider).createMultiPageDocument(
              pages: pages,
              subjectId: ref.read(archiveSubjectIdProvider),
              source: source,
              title: title,
              category: category,
              documentDate: documentDate,
              tags: tags,
              doctorName: doctorName,
              facilityName: facilityName,
              episode: episode,
              onProgress: onProgress,
            );
    await refresh();
    ref.invalidate(archiveUsageProvider);
    return document;
  }

  /// "Keep both": archives the duplicate notice.
  Future<void> dismissDuplicate(String documentId) async {
    final MedicalDocument updated =
        await ref.read(archiveRepositoryProvider).dismissDuplicate(documentId);
    if (state.hasValue) {
      state = AsyncValue<List<MedicalDocument>>.data(
        state.requireValue
            .map((MedicalDocument d) => d.id == documentId ? updated : d)
            .toList(growable: false),
      );
    }
    ref.invalidate(archiveDocumentProvider(documentId));
  }

  /// "Open the original": discards the new copy and returns the original id.
  Future<String> openOriginal(String newId) async {
    final String originalId =
        await ref.read(archiveRepositoryProvider).openOriginal(newId);
    await refresh();
    ref.invalidate(archiveUsageProvider);
    return originalId;
  }
}

final AsyncNotifierProvider<ArchiveListNotifier, List<MedicalDocument>>
    archiveListProvider =
    AsyncNotifierProvider<ArchiveListNotifier, List<MedicalDocument>>(
        ArchiveListNotifier.new);

/// Years available for the filter chips.
final FutureProvider<List<int>> archiveYearsProvider =
    FutureProvider<List<int>>((Ref ref) {
  ref.watch(archiveListProvider);
  return ref
      .read(archiveRepositoryProvider)
      .availableYears(subjectId: ref.read(archiveSubjectIdProvider));
});

/// Single document, by id.
final archiveDocumentProvider =
    FutureProvider.family<MedicalDocument?, String>(
        (Ref ref, String id) =>
            ref.watch(archiveRepositoryProvider).fetchById(id));

/// Pages of a document.
final archivePagesProvider = FutureProvider.family<List<DocumentPage>, String>(
    (Ref ref, String documentId) =>
        ref.watch(archiveRepositoryProvider).fetchPages(documentId));

/// Documents used and plan limit, read from `document_usage()`.
final FutureProvider<DocumentUsage> archiveUsageProvider =
    FutureProvider<DocumentUsage>(
        (Ref ref) => ref.watch(archiveRepositoryProvider).documentUsage());

/// 10-minute signed URL for a private object.
final archiveSignedUrlProvider = FutureProvider.family<String, String>(
    (Ref ref, String path) =>
        ref.watch(archiveRepositoryProvider).signedUrl(path));
