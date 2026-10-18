import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../document_service.dart';

/// Visual treatment applied to a scanned page.
enum ScanFilter {
  /// Untouched colours.
  original('Original'),

  /// Auto-contrast with a slight boost; good for faded photocopies.
  enhanced('Enhanced'),

  /// High-contrast black and white; smallest files, best for text.
  blackWhite('Black & White');

  final String label;
  const ScanFilter(this.label);
}

/// A finished scan ready to be attached as a document.
class ScanOutput {
  final Uint8List bytes;

  /// `jpg` for a single page, `pdf` for several.
  final String extension;
  final int pageCount;

  const ScanOutput({
    required this.bytes,
    required this.extension,
    required this.pageCount,
  });
}

class ScanTooLargeException implements Exception {
  final String message;
  const ScanTooLargeException(this.message);

  @override
  String toString() => message;
}

/// Image helpers for the document scanner. Heavy work runs in a background
/// isolate so the UI stays responsive on large scans.
class ImageProcessing {
  ImageProcessing._();

  /// Longest side kept for on-screen previews.
  static const int previewMaxSide = 1400;

  /// Longest side we keep for a freshly captured page.
  static const int captureMaxSide = 3600;

  /// Output ceiling, a little under the 10 MB upload limit so the encrypted
  /// file always fits.
  static const int maxOutputBytes = DocumentService.maxFileSizeBytes - 256 * 1024;

  // Quality ladder: (longest side, JPEG quality). Tried in order until the
  // result fits under [maxOutputBytes].
  static const List<(int, int)> _ladder = [
    (2480, 88),
    (2000, 80),
    (1600, 72),
    (1280, 64),
  ];

  /// Decodes a raw capture (scanner BMP/PNG/JPEG or webcam JPEG), fixes its
  /// orientation and caps its size. Returns JPEG bytes.
  static Future<Uint8List> normalize(Uint8List raw) =>
      compute(_normalizeSync, raw);

  static Future<Uint8List> rotate(Uint8List source, {bool clockwise = true}) =>
      compute(_rotateSync, (source, clockwise));

  /// Applies [filter] and downsizes to [maxSide]; returns JPEG bytes.
  static Future<Uint8List> render(
    Uint8List source,
    ScanFilter filter, {
    int maxSide = previewMaxSide,
    int quality = 85,
  }) => compute(_renderSync, (source, filter.index, maxSide, quality));

  /// Builds the final file. One page becomes a JPEG; several become a PDF.
  /// Tries progressively smaller output until it fits [maxOutputBytes].
  static Future<ScanOutput> export(
    List<Uint8List> sources,
    List<ScanFilter> filters,
  ) {
    if (sources.isEmpty) {
      throw ArgumentError('At least one page is required');
    }
    if (sources.length != filters.length) {
      throw ArgumentError('Each page needs a filter');
    }
    return compute(
      _exportAsync,
      (sources, filters.map((f) => f.index).toList()),
    );
  }
}

img.Image _decode(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('The image could not be read.');
  }
  return img.bakeOrientation(decoded);
}

img.Image _fit(img.Image image, int maxSide) {
  final longest = image.width > image.height ? image.width : image.height;
  if (longest <= maxSide) return image;
  return image.width >= image.height
      ? img.copyResize(
          image,
          width: maxSide,
          interpolation: img.Interpolation.average,
        )
      : img.copyResize(
          image,
          height: maxSide,
          interpolation: img.Interpolation.average,
        );
}

Uint8List _jpg(img.Image image, int quality) =>
    Uint8List.fromList(img.encodeJpg(image, quality: quality));

Uint8List _normalizeSync(Uint8List raw) {
  final image = _fit(_decode(raw), ImageProcessing.captureMaxSide);
  return _jpg(image, 92);
}

Uint8List _rotateSync((Uint8List, bool) args) {
  final image = _decode(args.$1);
  final rotated = img.copyRotate(image, angle: args.$2 ? 90 : -90);
  return _jpg(rotated, 92);
}

img.Image _applyFilter(img.Image image, ScanFilter filter) {
  switch (filter) {
    case ScanFilter.original:
      return image;
    case ScanFilter.enhanced:
      final stretched = img.normalize(image, min: 0, max: 255);
      return img.adjustColor(stretched, contrast: 1.18, brightness: 1.03);
    case ScanFilter.blackWhite:
      final gray = img.grayscale(img.Image.from(image));
      final stretched = img.normalize(gray, min: 0, max: 255);
      return img.luminanceThreshold(stretched, threshold: 0.58);
  }
}

Uint8List _renderSync((Uint8List, int, int, int) args) {
  final filter = ScanFilter.values[args.$2];
  final image = _fit(_decode(args.$1), args.$3);
  return _jpg(_applyFilter(image, filter), args.$4);
}

Future<Uint8List> _pdfAsync(List<(Uint8List, int, int)> pages) async {
  final doc = pw.Document(compress: true);
  for (final (jpg, width, height) in pages) {
    final landscape = width > height;
    final format = (landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4)
        .copyWith(
          marginLeft: 0,
          marginTop: 0,
          marginRight: 0,
          marginBottom: 0,
        );
    final image = pw.MemoryImage(jpg);
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) =>
            pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }
  return doc.save();
}

Future<ScanOutput> _exportAsync((List<Uint8List>, List<int>) args) async {
  final sources = args.$1;
  final filters = args.$2.map((i) => ScanFilter.values[i]).toList();
  final decoded = [for (final s in sources) _decode(s)];

  ScanOutput? last;
  for (final (maxSide, quality) in ImageProcessing._ladder) {
    final pages = <(Uint8List, int, int)>[];
    for (var i = 0; i < decoded.length; i++) {
      final fitted = _fit(decoded[i], maxSide);
      final filtered = _applyFilter(fitted, filters[i]);
      pages.add((_jpg(filtered, quality), filtered.width, filtered.height));
    }

    final output = pages.length == 1
        ? ScanOutput(bytes: pages.first.$1, extension: 'jpg', pageCount: 1)
        : ScanOutput(
            bytes: await _pdfAsync(pages),
            extension: 'pdf',
            pageCount: pages.length,
          );
    if (output.bytes.length <= ImageProcessing.maxOutputBytes) return output;
    last = output;
  }

  throw ScanTooLargeException(
    'The scan is too large (${DocumentService.formatFileSize(last!.bytes.length)}) '
    'even after compression. Remove some pages and try again.',
  );
}
