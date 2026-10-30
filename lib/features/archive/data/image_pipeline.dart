import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pdf_page;
import 'package:pdf/widgets.dart' as pdf_widgets;
import 'package:pdfrx/pdfrx.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/app_logger.dart';

/// Client-side normalisation of everything that enters the archive.
///
/// Rules (MASTER §15, Storage):
/// - accepted types: PDF, JPEG, PNG, HEIC; 25 MB per file;
/// - images become JPEG quality 85 with a 1600 px long side;
/// - EXIF and GPS are stripped; the EXIF capture date is read *before*
///   stripping and proposed as `document_date`;
/// - a 400 px thumbnail is produced for every page;
/// - PDFs are uploaded as-is; only the first page is rendered as thumbnail
///   and `page_count` is read from the file.
///
/// Nothing here touches Supabase and nothing is logged beyond error codes.
class ImagePipeline {
  const ImagePipeline();

  static const int maxBytes = 25 * 1024 * 1024;
  static const int longSide = 1600;
  static const int thumbSide = 400;
  static const int jpegQuality = 85;

  static const Set<String> allowedMimeTypes = <String>{
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/heic',
  };

  static bool _pdfInitialised = false;

  static void _ensurePdfInitialised() {
    if (_pdfInitialised) return;
    pdfrxFlutterInitialize();
    _pdfInitialised = true;
  }

  /// Best-effort mime detection from the first bytes of [bytes].
  /// The server (Edge Function `document-ingest`) repeats this check.
  static String? sniffMimeType(Uint8List bytes) {
    if (bytes.length >= 5 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2d) {
      return 'application/pdf';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12) {
      final String box = String.fromCharCodes(bytes.sublist(4, 8));
      final String brand = String.fromCharCodes(bytes.sublist(8, 12));
      const Set<String> heif = <String>{
        'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'hevm', 'hevs',
        'mif1', 'msf1',
      };
      if (box == 'ftyp' && heif.contains(brand.toLowerCase())) {
        return 'image/heic';
      }
    }
    return null;
  }

  static String extensionForMime(String mime) {
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

  /// Validates size and type before any upload starts.
  static void validate(Uint8List bytes) {
    if (bytes.isEmpty) throw ArchiveFailures.emptyFile;
    if (bytes.lengthInBytes > maxBytes) throw ArchiveFailures.fileTooLarge;
    final String? mime = sniffMimeType(bytes);
    if (mime == null || !allowedMimeTypes.contains(mime)) {
      throw ArchiveFailures.unsupportedType;
    }
  }

  /// Full normalisation of one picked file.
  Future<PreparedDocument> prepare(
    Uint8List bytes, {
    required String originalName,
  }) async {
    validate(bytes);
    final String mime = sniffMimeType(bytes)!;
    if (mime == 'application/pdf') {
      return _preparePdf(bytes, originalName: originalName);
    }
    return _prepareImage(bytes, mime: mime, originalName: originalName);
  }

  /// Normalises one raw photo (camera or gallery) into a numbered page.
  ///
  /// Same rules as [prepare]: orientation baked in, EXIF and GPS dropped,
  /// JPEG quality 85 on a 1600 px long side plus a 400 px thumbnail.
  /// Used by the multi-page flow, where the original is the composed PDF.
  Future<PreparedPage> preparePage(
    Uint8List bytes, {
    required int pageNumber,
  }) async {
    validate(bytes);
    final String mime = sniffMimeType(bytes)!;
    if (mime == 'application/pdf') throw ArchiveFailures.unsupportedType;

    Uint8List decodable = bytes;
    if (mime == 'image/heic') {
      if (kIsWeb) throw ArchiveFailures.heicNotSupportedOnWeb;
      try {
        decodable = await FlutterImageCompress.compressWithList(
          bytes,
          format: CompressFormat.jpeg,
          quality: 95,
          keepExif: false,
        );
      } catch (e) {
        AppLogger.error('archive.pipeline.heic', e);
        throw ArchiveFailures.unsupportedType;
      }
    }

    final img.Image? decoded = img.decodeImage(decodable);
    if (decoded == null) throw ArchiveFailures.unsupportedType;
    final img.Image upright = img.bakeOrientation(decoded);
    upright.exif = img.ExifData();
    return _encodePage(upright, pageNumber: pageNumber);
  }

  /// Rotates raw image bytes by [angle] degrees and re-encodes them as JPEG.
  /// Used by the camera/gallery editor before the page is normalised.
  static Uint8List rotate(Uint8List bytes, {int angle = 90}) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) throw ArchiveFailures.unsupportedType;
    return Uint8List.fromList(
      img.encodeJpg(img.copyRotate(decoded, angle: angle), quality: jpegQuality),
    );
  }

  /// Capture date of a raw photo, read before the EXIF block is stripped.
  DateTime? readCaptureDate(Uint8List bytes) {
    try {
      final img.Image? decoded = img.decodeImage(bytes);
      return decoded == null ? null : _readExifDate(decoded);
    } catch (e) {
      AppLogger.error('archive.pipeline.exifDate', e);
      return null;
    }
  }

  /// Builds `original.pdf` from the normalised pages: one page per image,
  /// no margin, page size equal to the image aspect ratio. Pure Dart, so
  /// it also runs on the web.
  Future<Uint8List> composePdf(List<PreparedPage> pages) async {
    if (pages.isEmpty) throw ArchiveFailures.emptyFile;
    final pdf_widgets.Document document = pdf_widgets.Document();
    for (final PreparedPage page in pages) {
      final pdf_widgets.MemoryImage image =
          pdf_widgets.MemoryImage(page.imageBytes);
      document.addPage(
        pdf_widgets.Page(
          pageFormat: pdf_page.PdfPageFormat(
            page.width.toDouble(),
            page.height.toDouble(),
          ),
          build: (pdf_widgets.Context context) => pdf_widgets.Image(
            image,
            fit: pdf_widgets.BoxFit.contain,
          ),
        ),
      );
    }
    final Uint8List bytes = await document.save();
    if (bytes.lengthInBytes > maxBytes) throw ArchiveFailures.fileTooLarge;
    return bytes;
  }

  // ---------------------------------------------------------------------
  // Images
  // ---------------------------------------------------------------------
  Future<PreparedDocument> _prepareImage(
    Uint8List bytes, {
    required String mime,
    required String originalName,
  }) async {
    Uint8List decodable = bytes;

    if (mime == 'image/heic') {
      if (kIsWeb) throw ArchiveFailures.heicNotSupportedOnWeb;
      try {
        decodable = await FlutterImageCompress.compressWithList(
          bytes,
          format: CompressFormat.jpeg,
          quality: 95,
          keepExif: false,
        );
      } catch (e) {
        AppLogger.error('archive.pipeline.heic', e);
        throw ArchiveFailures.unsupportedType;
      }
    }

    final img.Image? decoded = img.decodeImage(decodable);
    if (decoded == null) throw ArchiveFailures.unsupportedType;

    // 1. Read the capture date while the EXIF block is still there.
    final DateTime? captured = _readExifDate(decoded);

    // 2. Apply orientation, then drop every metadata block.
    final img.Image upright = img.bakeOrientation(decoded);
    upright.exif = img.ExifData();

    final PreparedPage page = _encodePage(upright, pageNumber: 1);

    return PreparedDocument(
      mimeType: 'image/jpeg',
      originalName: originalName,
      originalBytes: page.imageBytes,
      pageCount: 1,
      pages: <PreparedPage>[page],
      suggestedDate: captured,
    );
  }

  PreparedPage _encodePage(img.Image source, {required int pageNumber}) {
    final img.Image full = _fit(source, longSide);
    final img.Image thumb = _fit(source, thumbSide);
    return PreparedPage(
      pageNumber: pageNumber,
      imageBytes: Uint8List.fromList(img.encodeJpg(full, quality: jpegQuality)),
      thumbBytes: Uint8List.fromList(img.encodeJpg(thumb, quality: jpegQuality)),
      width: full.width,
      height: full.height,
    );
  }

  img.Image _fit(img.Image source, int maxSide) {
    final int w = source.width;
    final int h = source.height;
    if (w <= maxSide && h <= maxSide) return source;
    return w >= h
        ? img.copyResize(source, width: maxSide)
        : img.copyResize(source, height: maxSide);
  }

  DateTime? _readExifDate(img.Image image) {
    try {
      final img.ExifData exif = image.exif;
      final Object? raw = exif.exifIfd[0x9003]?.toString() ??
          exif.imageIfd[0x0132]?.toString();
      if (raw == null) return null;
      // EXIF format: "YYYY:MM:DD HH:MM:SS"
      final String text = raw.toString().trim();
      if (text.length < 10) return null;
      final String iso =
          '${text.substring(0, 4)}-${text.substring(5, 7)}-${text.substring(8, 10)}';
      return DateTime.tryParse(iso);
    } catch (e) {
      AppLogger.error('archive.pipeline.exif', e);
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // PDF
  // ---------------------------------------------------------------------
  Future<PreparedDocument> _preparePdf(
    Uint8List bytes, {
    required String originalName,
  }) async {
    _ensurePdfInitialised();

    int pageCount = 0;
    PreparedPage? thumbnail;
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openData(bytes);
      pageCount = doc.pages.length;
      if (pageCount > 0) {
        thumbnail = await _renderPdfThumbnail(doc.pages.first);
      }
    } catch (e) {
      AppLogger.error('archive.pipeline.pdf', e);
      throw ArchiveFailures.unsupportedType;
    } finally {
      await doc?.dispose();
    }

    return PreparedDocument(
      mimeType: 'application/pdf',
      originalName: originalName,
      originalBytes: bytes,
      pageCount: pageCount,
      pages: <PreparedPage>[if (thumbnail != null) thumbnail],
      suggestedDate: null,
    );
  }

  Future<PreparedPage?> _renderPdfThumbnail(PdfPage page) async {
    final double scale = longSide / (page.width > page.height ? page.width : page.height);
    final int targetW = (page.width * scale).round().clamp(1, longSide);
    final int targetH = (page.height * scale).round().clamp(1, longSide);

    final PdfImage? rendered = await page.render(
      fullWidth: targetW.toDouble(),
      fullHeight: targetH.toDouble(),
    );
    if (rendered == null) return null;

    try {
      final img.Image frame = img.Image.fromBytes(
        width: rendered.width,
        height: rendered.height,
        bytes: rendered.pixels.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      return _encodePage(frame, pageNumber: 1);
    } finally {
      rendered.dispose();
    }
  }
}

/// One normalised page ready for the Storage upload.
class PreparedPage {
  const PreparedPage({
    required this.pageNumber,
    required this.imageBytes,
    required this.thumbBytes,
    required this.width,
    required this.height,
  });

  final int pageNumber;
  final Uint8List imageBytes;
  final Uint8List thumbBytes;
  final int width;
  final int height;
}

/// Result of [ImagePipeline.prepare]: what goes to Storage, nothing more.
class PreparedDocument {
  const PreparedDocument({
    required this.mimeType,
    required this.originalName,
    required this.originalBytes,
    required this.pageCount,
    required this.pages,
    this.suggestedDate,
  });

  final String mimeType;
  final String originalName;
  final Uint8List originalBytes;
  final int pageCount;
  final List<PreparedPage> pages;

  /// Capture date read from EXIF before stripping; only a suggestion.
  final DateTime? suggestedDate;

  int get sizeBytes => originalBytes.lengthInBytes;
  String get extension => ImagePipeline.extensionForMime(mimeType);
}

/// Neutral, user-readable failures of the archive module.
class ArchiveFailures {
  const ArchiveFailures._();

  static const AppFailure emptyFile = AppFailure(
    'Il file è vuoto.',
    'The file is empty.',
    code: 'empty_file',
  );

  static const AppFailure fileTooLarge = AppFailure(
    'Il file supera 25 MB.',
    'The file is larger than 25 MB.',
    code: 'file_too_large',
  );

  static const AppFailure unsupportedType = AppFailure(
    'Formato non supportato. Usa PDF, JPG, PNG o HEIC.',
    'Unsupported format. Use PDF, JPG, PNG or HEIC.',
    code: 'unsupported_type',
  );

  static const AppFailure heicNotSupportedOnWeb = AppFailure(
    'I file HEIC si caricano dall\'app per iPhone o Android.',
    'HEIC files can be uploaded from the iPhone or Android app.',
    code: 'heic_web',
  );

  static const AppFailure limitReached = AppFailure(
    'Hai raggiunto il numero massimo di documenti del tuo piano.',
    'You have reached the document limit of your plan.',
    code: 'document_limit_reached',
  );

  static const AppFailure ingestFailed = AppFailure(
    'Il caricamento non è andato a buon fine. Riprova.',
    'The upload did not complete. Please try again.',
    code: 'ingest_failed',
  );
}
