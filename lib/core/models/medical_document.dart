/// Models of `public.documents` and `public.document_pages` (M2 Archivio).
///
/// No access filter lives here: the RLS policies decide what can be read.
library;

/// `document_category` enum.
enum DocumentCategory {
  exams('exams'),
  reports('reports'),
  prescriptions('prescriptions'),
  radiology('radiology'),
  vaccinations('vaccinations'),
  invoices('invoices'),
  consents('consents'),
  cards('cards'),
  other('other');

  const DocumentCategory(this.value);
  final String value;

  static DocumentCategory fromValue(String? v) => DocumentCategory.values
      .firstWhere((DocumentCategory c) => c.value == v,
          orElse: () => DocumentCategory.other);
}

/// `document_source` enum.
enum DocumentSource {
  camera('camera'),
  gallery('gallery'),
  pdf('pdf'),
  shareSheet('share_sheet'),
  email('email'),
  fse('fse');

  const DocumentSource(this.value);
  final String value;

  static DocumentSource fromValue(String? v) => DocumentSource.values
      .firstWhere((DocumentSource s) => s.value == v,
          orElse: () => DocumentSource.gallery);
}

/// `document_status` enum.
enum DocumentStatus {
  uploading('uploading'),
  uploaded('uploaded'),
  processing('processing'),
  analyzed('analyzed'),
  needsReview('needs_review'),
  failed('failed');

  const DocumentStatus(this.value);
  final String value;

  static DocumentStatus fromValue(String? v) => DocumentStatus.values
      .firstWhere((DocumentStatus s) => s.value == v,
          orElse: () => DocumentStatus.uploading);
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString());

List<String> _strings(Object? v) => v is List
    ? v.map((Object? e) => e.toString()).toList(growable: false)
    : const <String>[];

/// Row of `public.documents`.
class MedicalDocument {
  const MedicalDocument({
    required this.id,
    required this.ownerId,
    required this.subjectId,
    required this.storagePath,
    this.category = DocumentCategory.other,
    this.title = '',
    this.documentDate,
    this.source = DocumentSource.gallery,
    this.status = DocumentStatus.uploading,
    this.failureReason,
    this.originalName,
    this.mimeType,
    this.sizeBytes,
    this.pageCount = 0,
    this.sha256,
    this.duplicateOf,
    this.duplicateDismissedAt,
    this.tags = const <String>[],
    this.aiTags = const <String>[],
    this.doctorName,
    this.facilityName,
    this.episode,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String ownerId;
  final String subjectId;
  final String storagePath;
  final DocumentCategory category;
  final String title;
  final DateTime? documentDate;
  final DocumentSource source;
  final DocumentStatus status;
  final String? failureReason;
  final String? originalName;
  final String? mimeType;
  final int? sizeBytes;
  final int pageCount;
  final String? sha256;
  final String? duplicateOf;

  /// Set when the owner dismissed the "possible duplicate" notice.
  final DateTime? duplicateDismissedAt;
  final List<String> tags;

  /// Filled by the extraction engine (P02). Empty until then.
  final List<String> aiTags;
  final String? doctorName;
  final String? facilityName;
  final String? episode;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDuplicate => duplicateOf != null;

  /// True while the duplicate notice has not been dismissed yet.
  bool get showsDuplicateBadge =>
      duplicateOf != null && duplicateDismissedAt == null;
  bool get isPdf => mimeType == 'application/pdf';

  /// Year used to group the list on the client.
  int? get year => (documentDate ?? createdAt)?.year;

  String get originalPath =>
      '$storagePath/original.${_extensionForMime(mimeType)}';

  String pagePath(int pageNumber) =>
      '$storagePath/page-${pageNumber.toString().padLeft(3, '0')}.jpg';

  String thumbPath(int pageNumber) =>
      '$storagePath/thumb-${pageNumber.toString().padLeft(3, '0')}.jpg';

  static String _extensionForMime(String? mime) {
    switch (mime) {
      case 'application/pdf':
        return 'pdf';
      case 'image/png':
        return 'png';
      case 'image/heic':
        return 'heic';
      default:
        return 'jpg';
    }
  }

  factory MedicalDocument.fromJson(Map<String, dynamic> json) =>
      MedicalDocument(
        id: json['id'].toString(),
        ownerId: json['owner_id'].toString(),
        subjectId: json['subject_id'].toString(),
        storagePath: (json['storage_path'] ?? '').toString(),
        category: DocumentCategory.fromValue(json['category'] as String?),
        title: (json['title'] ?? '').toString(),
        documentDate: _date(json['document_date']),
        source: DocumentSource.fromValue(json['source'] as String?),
        status: DocumentStatus.fromValue(json['status'] as String?),
        failureReason: json['failure_reason'] as String?,
        originalName: json['original_name'] as String?,
        mimeType: json['mime_type'] as String?,
        sizeBytes: (json['size_bytes'] as num?)?.toInt(),
        pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
        sha256: json['sha256'] as String?,
        duplicateOf: json['duplicate_of']?.toString(),
        duplicateDismissedAt: _date(json['duplicate_dismissed_at']),
        tags: _strings(json['tags']),
        aiTags: _strings(json['ai_tags']),
        doctorName: json['doctor_name'] as String?,
        facilityName: json['facility_name'] as String?,
        episode: json['episode'] as String?,
        notes: json['notes'] as String?,
        createdAt: _date(json['created_at']),
        updatedAt: _date(json['updated_at']),
        deletedAt: _date(json['deleted_at']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'owner_id': ownerId,
        'subject_id': subjectId,
        'storage_path': storagePath,
        'category': category.value,
        'title': title,
        'document_date': documentDate?.toIso8601String().substring(0, 10),
        'source': source.value,
        'status': status.value,
        'failure_reason': failureReason,
        'original_name': originalName,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'page_count': pageCount,
        'sha256': sha256,
        'duplicate_of': duplicateOf,
        'duplicate_dismissed_at': duplicateDismissedAt?.toIso8601String(),
        'tags': tags,
        'ai_tags': aiTags,
        'doctor_name': doctorName,
        'facility_name': facilityName,
        'episode': episode,
        'notes': notes,
      };

  MedicalDocument copyWith({
    DocumentCategory? category,
    String? title,
    DateTime? documentDate,
    DocumentStatus? status,
    String? failureReason,
    int? pageCount,
    String? sha256,
    String? duplicateOf,
    DateTime? duplicateDismissedAt,
    List<String>? tags,
    List<String>? aiTags,
    String? doctorName,
    String? facilityName,
    String? episode,
    String? notes,
    DateTime? deletedAt,
  }) =>
      MedicalDocument(
        id: id,
        ownerId: ownerId,
        subjectId: subjectId,
        storagePath: storagePath,
        category: category ?? this.category,
        title: title ?? this.title,
        documentDate: documentDate ?? this.documentDate,
        source: source,
        status: status ?? this.status,
        failureReason: failureReason ?? this.failureReason,
        originalName: originalName,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        pageCount: pageCount ?? this.pageCount,
        sha256: sha256 ?? this.sha256,
        duplicateOf: duplicateOf ?? this.duplicateOf,
        duplicateDismissedAt: duplicateDismissedAt ?? this.duplicateDismissedAt,
        tags: tags ?? this.tags,
        aiTags: aiTags ?? this.aiTags,
        doctorName: doctorName ?? this.doctorName,
        facilityName: facilityName ?? this.facilityName,
        episode: episode ?? this.episode,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}

/// Row of `public.document_pages`.
class DocumentPage {
  const DocumentPage({
    required this.id,
    required this.documentId,
    required this.pageNumber,
    this.imagePath,
    this.thumbPath,
    this.width,
    this.height,
    this.ocrText,
    this.createdAt,
  });

  final String id;
  final String documentId;
  final int pageNumber;
  final String? imagePath;
  final String? thumbPath;
  final int? width;
  final int? height;

  /// Filled by the extraction engine (P02).
  final String? ocrText;
  final DateTime? createdAt;

  factory DocumentPage.fromJson(Map<String, dynamic> json) => DocumentPage(
        id: json['id'].toString(),
        documentId: json['document_id'].toString(),
        pageNumber: (json['page_number'] as num).toInt(),
        imagePath: json['image_path'] as String?,
        thumbPath: json['thumb_path'] as String?,
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        ocrText: json['ocr_text'] as String?,
        createdAt: _date(json['created_at']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'document_id': documentId,
        'page_number': pageNumber,
        'image_path': imagePath,
        'thumb_path': thumbPath,
        'width': width,
        'height': height,
      };
}
