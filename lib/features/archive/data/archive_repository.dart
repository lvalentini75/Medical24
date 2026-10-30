import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/medical_document.dart';
import '../../../core/utils/app_logger.dart';
import '../../../supabase/supabase_config.dart';
import 'image_pipeline.dart';
import 'temp_file.dart';

/// Single entry point to `documents`, `document_pages` and the private
/// `documents` bucket. No Supabase query for the archive lives outside
/// this class, and no access filter is written here: RLS decides, through
/// `can_access_subject(subject_id)`.
class ArchiveRepository {
  const ArchiveRepository({this.pipeline = const ImagePipeline()});

  final ImagePipeline pipeline;

  static const String bucket = 'documents';
  static const String _table = 'documents';
  static const String _pagesTable = 'document_pages';
  static const Uuid _uuid = Uuid();

  SupabaseClient get _db => SupabaseConfig.client;

  String get _uid {
    final String? uid = SupabaseConfig.currentUserId;
    if (uid == null) throw AppFailure.unauthorized;
    return uid;
  }

  /// `subjects/{subject_id}/documents/{document_id}`
  static String storageFolder(String subjectId, String documentId) =>
      'subjects/$subjectId/documents/$documentId';

  // -------------------------------------------------------------------------
  // Create / upload / finalize
  // -------------------------------------------------------------------------

  /// Inserts the `uploading` row. The id is generated client-side so the
  /// storage path is known before the first byte is sent.
  Future<MedicalDocument> createDocument({
    String? subjectId,
    required DocumentSource source,
    String title = '',
    DocumentCategory category = DocumentCategory.other,
    DateTime? documentDate,
    String? originalName,
    String? mimeType,
    int? sizeBytes,
    List<String> tags = const <String>[],
    String? doctorName,
    String? facilityName,
    String? episode,
    String? notes,
  }) async {
    final String owner = _uid;
    final String subject = subjectId ?? owner;
    final String id = _uuid.v4();

    try {
      final Map<String, dynamic> row = await _db
          .from(_table)
          .insert(<String, dynamic>{
            'id': id,
            'owner_id': owner,
            'subject_id': subject,
            'storage_path': storageFolder(subject, id),
            'category': category.value,
            'title': title,
            'document_date': documentDate?.toIso8601String().substring(0, 10),
            'source': source.value,
            'status': DocumentStatus.uploading.value,
            'original_name': originalName,
            'mime_type': mimeType,
            'size_bytes': sizeBytes,
            'tags': tags,
            'doctor_name': doctorName,
            'facility_name': facilityName,
            'episode': episode,
            'notes': notes,
          })
          .select()
          .single();
      AppLogger.event('document_created');
      return MedicalDocument.fromJson(row);
    } catch (e) {
      throw _mapError(e, 'archive.createDocument');
    }
  }

  /// Uploads `original.{ext}` into the document folder.
  Future<String> uploadOriginal(
    MedicalDocument document, {
    required Uint8List bytes,
    required String mimeType,
  }) async {
    ImagePipeline.validate(bytes);
    final String path =
        '${document.storagePath}/original.${ImagePipeline.extensionForMime(mimeType)}';
    try {
      await _db.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );
      return path;
    } catch (e) {
      throw _mapError(e, 'archive.uploadOriginal');
    }
  }

  /// Uploads `page-NNN.jpg` + `thumb-NNN.jpg` and inserts the page row.
  Future<DocumentPage> uploadPage(
    MedicalDocument document,
    PreparedPage page,
  ) async {
    final String suffix = page.pageNumber.toString().padLeft(3, '0');
    final String imagePath = '${document.storagePath}/page-$suffix.jpg';
    final String thumbPath = '${document.storagePath}/thumb-$suffix.jpg';

    try {
      await _db.storage.from(bucket).uploadBinary(
            imagePath,
            page.imageBytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      await _db.storage.from(bucket).uploadBinary(
            thumbPath,
            page.thumbBytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final Map<String, dynamic> row = await _db
          .from(_pagesTable)
          .upsert(<String, dynamic>{
            'document_id': document.id,
            'page_number': page.pageNumber,
            'image_path': imagePath,
            'thumb_path': thumbPath,
            'width': page.width,
            'height': page.height,
          }, onConflict: 'document_id,page_number')
          .select()
          .single();
      return DocumentPage.fromJson(row);
    } catch (e) {
      throw _mapError(e, 'archive.uploadPage');
    }
  }

  /// Server-side validation and finalisation (`document-ingest`):
  /// magic bytes, size, sha256, duplicate detection, audit.
  Future<IngestResult> finalize(String documentId) async {
    try {
      final FunctionResponse response = await _db.functions.invoke(
        'document-ingest',
        body: <String, dynamic>{'document_id': documentId},
      );
      final Map<String, dynamic> data =
          Map<String, dynamic>.from((response.data ?? <String, dynamic>{}) as Map);
      final String status = (data['status'] ?? 'failed').toString();
      AppLogger.event('document_ingested', meta: <String, Object?>{
        'status': status,
      });
      if (status != 'uploaded') throw ArchiveFailures.ingestFailed;
      return IngestResult(
        status: DocumentStatus.fromValue(status),
        duplicateOf: data['duplicate_of']?.toString(),
      );
    } on FunctionException {
      AppLogger.error('archive.finalize', 'FunctionException');
      throw ArchiveFailures.ingestFailed;
    } catch (e) {
      throw _mapError(e, 'archive.finalize');
    }
  }

  /// Full upload of one picked file: prepare → create → upload → finalize.
  Future<MedicalDocument> ingestFile({
    required Uint8List bytes,
    required String originalName,
    required DocumentSource source,
    String? subjectId,
    String title = '',
    DocumentCategory category = DocumentCategory.other,
    DateTime? documentDate,
    List<String> tags = const <String>[],
  }) async {
    final PreparedDocument prepared =
        await pipeline.prepare(bytes, originalName: originalName);

    final MedicalDocument document = await createDocument(
      subjectId: subjectId,
      source: source,
      title: title,
      category: category,
      documentDate: documentDate ?? prepared.suggestedDate,
      originalName: originalName,
      mimeType: prepared.mimeType,
      sizeBytes: prepared.sizeBytes,
      tags: tags,
    );

    await uploadOriginal(document,
        bytes: prepared.originalBytes, mimeType: prepared.mimeType);
    for (final PreparedPage page in prepared.pages) {
      await uploadPage(document, page);
    }

    final IngestResult result = await finalize(document.id);
    return document.copyWith(
      status: result.status,
      duplicateOf: result.duplicateOf,
      pageCount: prepared.pageCount,
    );
  }

  /// Multi-page document built from camera or gallery shots.
  ///
  /// Project decision (P01-D): a document always has an original. For photo
  /// documents the original is a PDF composed on the client from the
  /// normalised pages and stored as `original.pdf` next to `page-NNN.jpg`
  /// and `thumb-NNN.jpg`. The Edge Function sets `page_count` from the
  /// pages actually uploaded and hashes the original.
  ///
  /// [onProgress] reports `(done, total)` after every page.
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
    if (pages.isEmpty) throw ArchiveFailures.emptyFile;

    // Pages are normalised first: nothing is created server-side if one of
    // the shots is unreadable or too large.
    final List<PreparedPage> prepared = <PreparedPage>[];
    for (int i = 0; i < pages.length; i++) {
      prepared.add(await pipeline.preparePage(pages[i], pageNumber: i + 1));
    }
    final Uint8List original = await pipeline.composePdf(prepared);

    final MedicalDocument document = await createDocument(
      subjectId: subjectId,
      source: source,
      title: title,
      category: category,
      documentDate: documentDate ?? pipeline.readCaptureDate(pages.first),
      originalName: 'original.pdf',
      mimeType: 'application/pdf',
      sizeBytes: original.lengthInBytes,
      tags: tags,
      doctorName: doctorName,
      facilityName: facilityName,
      episode: episode,
      notes: notes,
    );

    final int total = prepared.length + 1;
    int done = 0;
    for (final PreparedPage page in prepared) {
      await uploadPage(document, page);
      done++;
      onProgress?.call(done, total);
    }

    await uploadOriginal(document,
        bytes: original, mimeType: 'application/pdf');
    onProgress?.call(total, total);

    final IngestResult result = await finalize(document.id);
    return document.copyWith(
      status: result.status,
      duplicateOf: result.duplicateOf,
      pageCount: prepared.length,
    );
  }

  // -------------------------------------------------------------------------
  // Plan limit
  // -------------------------------------------------------------------------

  /// `document_usage()`: active documents of the current subject and the
  /// limit of the plan. The count comes from Postgres under RLS, never
  /// from a client-side filter.
  Future<DocumentUsage> documentUsage() async {
    try {
      final dynamic data = await SupabaseConfig.rpc('document_usage');
      final Map<String, dynamic>? row = data is List
          ? (data.isEmpty ? null : Map<String, dynamic>.from(data.first as Map))
          : (data is Map ? Map<String, dynamic>.from(data) : null);
      if (row == null) return const DocumentUsage(used: 0, max: 0);
      return DocumentUsage(
        used: (row['used'] as num?)?.toInt() ?? 0,
        max: (row['max'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw _mapError(e, 'archive.documentUsage');
    }
  }

  // -------------------------------------------------------------------------
  // Duplicates
  // -------------------------------------------------------------------------

  /// "Keep both": the notice is archived and the list stops showing the
  /// "possible duplicate" label for this document.
  Future<MedicalDocument> dismissDuplicate(String documentId) async {
    try {
      final Map<String, dynamic> row = await _db
          .from(_table)
          .update(<String, dynamic>{
            'duplicate_dismissed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', documentId)
          .select()
          .single();
      AppLogger.event('document_duplicate_dismissed');
      return MedicalDocument.fromJson(row);
    } catch (e) {
      throw _mapError(e, 'archive.dismissDuplicate');
    }
  }

  /// "Open the original": the freshly uploaded copy is soft deleted and the
  /// id of the document it duplicates is returned.
  Future<String> openOriginal(String newId) async {
    try {
      final MedicalDocument? copy = await fetchById(newId);
      if (copy == null) throw AppFailure.unauthorized;
      final String? original = copy.duplicateOf;
      if (original == null) return newId;
      await softDelete(copy);
      AppLogger.event('document_duplicate_discarded');
      return original;
    } catch (e) {
      throw _mapError(e, 'archive.openOriginal');
    }
  }

  // -------------------------------------------------------------------------
  // Share
  // -------------------------------------------------------------------------

  /// Downloads the original through a 600-second signed URL and returns it
  /// as an [XFile]: a temporary file on iOS/Android, bytes in memory on the
  /// web. No public link is ever created. The caller deletes the file with
  /// [disposeSharedFile] once the share sheet closes.
  Future<XFile> shareFile(String documentId) async {
    try {
      final MedicalDocument? document = await fetchById(documentId);
      if (document == null) throw AppFailure.unauthorized;

      // The 600-second signed URL is what authorises the read: it is issued
      // first and the bytes are fetched through it by the storage client.
      await signedUrl(document.originalPath, expiresInSeconds: 600);
      final Uint8List bytes = await download(document.originalPath);

      final String extension =
          ImagePipeline.extensionForMime(document.mimeType ?? '');
      final String name = (document.originalName ?? '').trim().isEmpty
          ? 'document-${document.id}.$extension'
          : document.originalName!;
      AppLogger.event('document_shared');
      return writeTempFile(bytes,
          name: name, mimeType: document.mimeType ?? 'application/octet-stream');
    } catch (e) {
      throw _mapError(e, 'archive.shareFile');
    }
  }

  /// Removes the temporary file produced by [shareFile].
  Future<void> disposeSharedFile(XFile file) => deleteTempFile(file);

  // -------------------------------------------------------------------------
  // Read
  // -------------------------------------------------------------------------

  /// Keyset pagination on `(document_date desc, id desc)`.
  Future<DocumentPage2> list({
    String? subjectId,
    DocumentCategory? category,
    int? year,
    DocumentStatus? status,
    String? search,
    ArchiveSort sort = ArchiveSort.dateDesc,
    ArchiveCursor? cursor,
    int limit = 30,
  }) async {
    final String subject = subjectId ?? _uid;
    try {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _db
          .from(_table)
          .select('*, document_pages(id, page_number, thumb_path)')
          .eq('subject_id', subject);

      if (category != null) query = query.eq('category', category.value);
      if (status != null) query = query.eq('status', status.value);
      if (year != null) {
        query = query
            .gte('document_date', '$year-01-01')
            .lte('document_date', '$year-12-31');
      }
      final String? terms = search?.trim();
      if (terms != null && terms.isNotEmpty) {
        query = query.textSearch('search', terms,
            config: 'simple', type: TextSearchType.websearch);
      }

      PostgrestTransformBuilder<List<Map<String, dynamic>>> ordered;
      switch (sort) {
        case ArchiveSort.dateDesc:
          if (cursor?.documentDate != null) {
            query = query.or(
              'document_date.lt.${cursor!.documentDate},'
              'and(document_date.eq.${cursor.documentDate},id.lt.${cursor.id})',
            );
          }
          ordered = query
              .order('document_date', ascending: false, nullsFirst: false)
              .order('id', ascending: false);
        case ArchiveSort.dateAsc:
          ordered = query
              .order('document_date', ascending: true, nullsFirst: false)
              .order('id', ascending: true);
        case ArchiveSort.category:
          ordered = query
              .order('category', ascending: true)
              .order('document_date', ascending: false, nullsFirst: false);
        case ArchiveSort.doctor:
          ordered = query
              .order('doctor_name', ascending: true, nullsFirst: false)
              .order('document_date', ascending: false, nullsFirst: false);
        case ArchiveSort.facility:
          ordered = query
              .order('facility_name', ascending: true, nullsFirst: false)
              .order('document_date', ascending: false, nullsFirst: false);
      }

      final int offset = sort == ArchiveSort.dateDesc ? 0 : (cursor?.offset ?? 0);
      final List<Map<String, dynamic>> rows =
          await ordered.range(offset, offset + limit - 1);

      final List<MedicalDocument> items = rows
          .map((Map<String, dynamic> r) => MedicalDocument.fromJson(r))
          .toList(growable: false);

      ArchiveCursor? next;
      if (items.length == limit) {
        final MedicalDocument last = items.last;
        next = ArchiveCursor(
          documentDate: last.documentDate?.toIso8601String().substring(0, 10),
          id: last.id,
          offset: offset + limit,
        );
      }
      return DocumentPage2(items: items, nextCursor: next);
    } catch (e) {
      throw _mapError(e, 'archive.list');
    }
  }

  Future<MedicalDocument?> fetchById(String documentId) async {
    try {
      final Map<String, dynamic>? row =
          await _db.from(_table).select().eq('id', documentId).maybeSingle();
      return row == null ? null : MedicalDocument.fromJson(row);
    } catch (e) {
      throw _mapError(e, 'archive.fetchById');
    }
  }

  Future<List<DocumentPage>> fetchPages(String documentId) async {
    try {
      final List<Map<String, dynamic>> rows = await _db
          .from(_pagesTable)
          .select()
          .eq('document_id', documentId)
          .order('page_number');
      return rows
          .map((Map<String, dynamic> r) => DocumentPage.fromJson(r))
          .toList(growable: false);
    } catch (e) {
      throw _mapError(e, 'archive.fetchPages');
    }
  }

  /// Distinct years available for the filter chips.
  Future<List<int>> availableYears({String? subjectId}) async {
    final String subject = subjectId ?? _uid;
    try {
      final List<Map<String, dynamic>> rows = await _db
          .from(_table)
          .select('document_date')
          .eq('subject_id', subject)
          .not('document_date', 'is', null)
          .order('document_date', ascending: false);
      final Set<int> years = <int>{};
      for (final Map<String, dynamic> r in rows) {
        final DateTime? d = DateTime.tryParse(r['document_date'].toString());
        if (d != null) years.add(d.year);
      }
      return years.toList()..sort((int a, int b) => b.compareTo(a));
    } catch (e) {
      throw _mapError(e, 'archive.availableYears');
    }
  }

  // -------------------------------------------------------------------------
  // Client-side grouping (no extra query)
  // -------------------------------------------------------------------------

  static Map<int, List<MedicalDocument>> groupByYear(
      List<MedicalDocument> items) {
    final Map<int, List<MedicalDocument>> grouped =
        <int, List<MedicalDocument>>{};
    for (final MedicalDocument d in items) {
      grouped.putIfAbsent(d.year ?? 0, () => <MedicalDocument>[]).add(d);
    }
    return grouped;
  }

  static Map<String, List<MedicalDocument>> groupByEpisode(
      List<MedicalDocument> items) {
    final Map<String, List<MedicalDocument>> grouped =
        <String, List<MedicalDocument>>{};
    for (final MedicalDocument d in items) {
      final String key = (d.episode ?? '').trim();
      grouped.putIfAbsent(key, () => <MedicalDocument>[]).add(d);
    }
    return grouped;
  }

  // -------------------------------------------------------------------------
  // Update / delete
  // -------------------------------------------------------------------------

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
    final Map<String, dynamic> values = <String, dynamic>{
      if (title != null) 'title': title,
      if (category != null) 'category': category.value,
      if (documentDate != null)
        'document_date': documentDate.toIso8601String().substring(0, 10),
      if (tags != null) 'tags': tags,
      if (doctorName != null) 'doctor_name': doctorName,
      if (facilityName != null) 'facility_name': facilityName,
      if (episode != null) 'episode': episode,
      if (notes != null) 'notes': notes,
    };
    if (values.isEmpty) {
      final MedicalDocument? current = await fetchById(documentId);
      if (current == null) throw AppFailure.unauthorized;
      return current;
    }
    try {
      final Map<String, dynamic> row = await _db
          .from(_table)
          .update(values)
          .eq('id', documentId)
          .select()
          .single();
      AppLogger.event('document_updated');
      return MedicalDocument.fromJson(row);
    } catch (e) {
      throw _mapError(e, 'archive.updateMetadata');
    }
  }

  /// Soft delete through Postgres, then remove the objects from the private
  /// bucket. The database trigger writes the audit entry.
  Future<void> softDelete(MedicalDocument document) async {
    try {
      await _db.rpc('soft_delete_document',
          params: <String, dynamic>{'p_document_id': document.id});

      final List<FileObject> objects =
          await _db.storage.from(bucket).list(path: document.storagePath);
      if (objects.isNotEmpty) {
        await _db.storage.from(bucket).remove(
              objects
                  .map((FileObject o) => '${document.storagePath}/${o.name}')
                  .toList(growable: false),
            );
      }
      AppLogger.event('document_deleted');
    } catch (e) {
      throw _mapError(e, 'archive.softDelete');
    }
  }

  // -------------------------------------------------------------------------
  // Storage access
  // -------------------------------------------------------------------------

  /// Short-lived signed URL (10 minutes) for a private object.
  Future<String> signedUrl(String path, {int expiresInSeconds = 600}) async {
    try {
      return await SupabaseConfig.createSignedUrl(
        bucket,
        path,
        expiresInSeconds: expiresInSeconds,
      );
    } catch (e) {
      throw _mapError(e, 'archive.signedUrl');
    }
  }

  Future<Uint8List> download(String path) async {
    try {
      return await _db.storage.from(bucket).download(path);
    } catch (e) {
      throw _mapError(e, 'archive.download');
    }
  }

  // -------------------------------------------------------------------------
  AppFailure _mapError(Object error, String where) {
    if (error is AppFailure) return error;
    if (error is PostgrestException &&
        (error.message.contains('document_limit_reached'))) {
      AppLogger.error(where, 'document_limit_reached');
      return ArchiveFailures.limitReached;
    }
    return AppFailure.from(error, where: where);
  }
}

/// Result of the `document-ingest` Edge Function.
class IngestResult {
  const IngestResult({required this.status, this.duplicateOf});
  final DocumentStatus status;
  final String? duplicateOf;
}

/// Result of `document_usage()`: active documents and plan limit.
class DocumentUsage {
  const DocumentUsage({required this.used, required this.max});

  final int used;
  final int max;

  bool get isLimitReached => max > 0 && used >= max;
  int get remaining => max <= 0 ? 0 : (max - used).clamp(0, max);
}

/// Keyset cursor on `(document_date, id)`.
class ArchiveCursor {
  const ArchiveCursor({this.documentDate, required this.id, this.offset = 0});
  final String? documentDate;
  final String id;
  final int offset;
}

/// One page of archive results.
class DocumentPage2 {
  const DocumentPage2({required this.items, this.nextCursor});
  final List<MedicalDocument> items;
  final ArchiveCursor? nextCursor;
  bool get hasMore => nextCursor != null;
}

/// Sort orders offered by the archive list (MASTER, M2).
enum ArchiveSort { dateDesc, dateAsc, category, doctor, facility }
