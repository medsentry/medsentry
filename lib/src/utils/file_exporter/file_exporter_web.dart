import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

import 'file_exporter_interface.dart';

class WebFileExporter implements FileExporter {
  @override
  Future<String> exportTextFile({
    required String filename,
    required String content,
  }) async {
    await Share.shareXFiles([
      XFile.fromData(
        Uint8List.fromList(content.codeUnits),
        name: filename,
        mimeType: filename.endsWith('.csv') ? 'text/csv' : 'application/json',
      ),
    ], subject: filename);
    return filename;
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
