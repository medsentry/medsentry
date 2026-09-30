import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'file_exporter_interface.dart';

class IoFileExporter implements FileExporter {
  @override
  Future<String> exportTextFile({
    required String filename,
    required String content,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  @override
  Future<void> shareFile(
    String filePath, {
    required String subject,
    required String text,
  }) async {
    await Share.shareXFiles([XFile(filePath)], subject: subject, text: text);
  }
}

FileExporter createFileExporter() => IoFileExporter();
