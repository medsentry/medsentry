import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'package:web/web.dart' as web;

import 'file_exporter_interface.dart';

class WebFileExporter implements FileExporter {
  String _download({
    required String filename,
    required web.Blob blob,
    required Duration revokeAfter,
  }) {
    final objectUrl = web.URL.createObjectURL(blob);
    final link = web.HTMLAnchorElement()
      ..href = objectUrl
      ..download = filename
      ..style.display = 'none';
    final body = web.document.body;
    if (body == null) {
      web.URL.revokeObjectURL(objectUrl);
      throw StateError(
        'Cannot download a file because the document is unavailable.',
      );
    }

    body.append(link);
    link.click();
    link.remove();
    unawaited(
      Future<void>.delayed(
        revokeAfter,
        () => web.URL.revokeObjectURL(objectUrl),
      ),
    );
    return filename;
  }

  @override
  Future<String> exportTextFile({
    required String filename,
    required String content,
  }) async {
    final mimeType = filename.endsWith('.csv')
        ? 'text/csv'
        : 'application/json';
    return _download(
      filename: filename,
      blob: web.Blob([content.toJS].toJS, web.BlobPropertyBag(type: mimeType)),
      revokeAfter: const Duration(seconds: 1),
    );
  }

  @override
  Future<String?> saveBinaryFile({
    required String filename,
    required Uint8List bytes,
    String? dialogTitle,
    String mimeType = 'application/pdf',
  }) async {
    return _download(
      filename: filename,
      blob: web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType)),
      revokeAfter: const Duration(seconds: 2),
    );
  }

  @override
  Future<bool> openFile(String filePath) async {
    return false;
  }

  @override
  Future<void> shareFile(
    String filePath, {
    required String subject,
    required String text,
  }) async {
    await Share.share(text, subject: subject);
  }
}

FileExporter createFileExporter() => WebFileExporter();
