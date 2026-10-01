import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

import 'file_exporter_interface.dart';

class WebFileExporter implements FileExporter {
  @override
  Future<String> exportTextFile({
    required String filename,
    required String content,
  }) async {
    final mimeType = filename.endsWith('.csv')
        ? 'text/csv'
        : 'application/json';
    final blob = html.Blob([utf8.encode(content)], mimeType);
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);
    final downloadLink = html.AnchorElement(href: objectUrl)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.children.add(downloadLink);
    downloadLink.click();
    downloadLink.remove();
    unawaited(
      Future<void>.delayed(
        const Duration(seconds: 1),
        () => html.Url.revokeObjectUrl(objectUrl),
      ),
    );
    return filename;
  }

  @override
  Future<String?> saveBinaryFile({
    required String filename,
    required Uint8List bytes,
    String? dialogTitle,
    String mimeType = 'application/pdf',
  }) async {
    final blob = html.Blob([bytes], mimeType);
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);
    final downloadLink = html.AnchorElement(href: objectUrl)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.children.add(downloadLink);
    downloadLink.click();
    downloadLink.remove();
    unawaited(
      Future<void>.delayed(
        const Duration(seconds: 2),
        () => html.Url.revokeObjectUrl(objectUrl),
      ),
    );
    return filename;
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
