import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:medsentry/src/services/document_service.dart';
import 'package:medsentry/src/services/scanner/image_processing.dart';

Uint8List _png(int width, int height, {bool noise = false, int seed = 1}) {
  final random = Random(seed);
  final image = img.Image(width: width, height: height);
  for (final p in image) {
    if (noise) {
      p
        ..r = random.nextInt(256)
        ..g = random.nextInt(256)
        ..b = random.nextInt(256);
    } else {
      p
        ..r = (p.x * 255) ~/ width
        ..g = (p.y * 255) ~/ height
        ..b = 128;
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

img.Image _decode(Uint8List bytes) => img.decodeImage(bytes)!;

void main() {
  test('normalize caps the longest side and returns a JPEG', () async {
    final raw = _png(5000, 3000);
    final normalized = await ImageProcessing.normalize(raw);

    final decoded = _decode(normalized);
    expect(decoded.width, ImageProcessing.captureMaxSide);
    expect(decoded.height, lessThan(decoded.width));
    // JPEG magic number.
    expect(normalized[0], 0xFF);
    expect(normalized[1], 0xD8);
  });

  test('rotate swaps width and height in both directions', () async {
    final source = await ImageProcessing.normalize(_png(800, 400));

    final cw = _decode(await ImageProcessing.rotate(source));
    expect((cw.width, cw.height), (400, 800));

    final ccw = _decode(
      await ImageProcessing.rotate(source, clockwise: false),
    );
    expect((ccw.width, ccw.height), (400, 800));
  });

  test('render applies every filter and respects the size cap', () async {
    final source = await ImageProcessing.normalize(_png(2000, 1000));

    for (final filter in ScanFilter.values) {
      final out = _decode(
        await ImageProcessing.render(source, filter, maxSide: 500),
      );
      expect(out.width, 500, reason: filter.label);
    }

    // Black & white output only contains near-black or near-white pixels.
    final bw = _decode(
      await ImageProcessing.render(
        source,
        ScanFilter.blackWhite,
        maxSide: 200,
        quality: 100,
      ),
    );
    var extremes = 0;
    var total = 0;
    for (final p in bw) {
      total++;
      if (p.r < 40 || p.r > 215) extremes++;
    }
    expect(extremes / total, greaterThan(0.95));
  });

  test('single page exports as a JPEG, several pages as a PDF', () async {
    final page = await ImageProcessing.normalize(_png(1200, 1600));

    final single = await ImageProcessing.export(
      [page],
      [ScanFilter.enhanced],
    );
    expect(single.extension, 'jpg');
    expect(single.pageCount, 1);

    final multi = await ImageProcessing.export(
      [page, page, page],
      [ScanFilter.original, ScanFilter.enhanced, ScanFilter.blackWhite],
    );
    expect(multi.extension, 'pdf');
    expect(multi.pageCount, 3);
    expect(String.fromCharCodes(multi.bytes.take(5)), '%PDF-');
  });

  test('large noisy scans are compressed to fit the upload limit', () async {
    final pages = <Uint8List>[];
    for (var i = 0; i < 6; i++) {
      pages.add(
        await ImageProcessing.normalize(
          _png(2400, 3200, noise: true, seed: i),
        ),
      );
    }

    final output = await ImageProcessing.export(
      pages,
      List.filled(pages.length, ScanFilter.original),
    );

    expect(output.extension, 'pdf');
    expect(output.bytes.length, lessThanOrEqualTo(ImageProcessing.maxOutputBytes));
    expect(
      output.bytes.length,
      lessThanOrEqualTo(DocumentService.maxFileSizeBytes),
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('export validates its input', () {
    expect(() => ImageProcessing.export([], []), throwsArgumentError);
    expect(
      () => ImageProcessing.export([Uint8List(1)], []),
      throwsArgumentError,
    );
  });
}

