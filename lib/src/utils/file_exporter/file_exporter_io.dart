import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
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
  Future<String?> saveBinaryFile({
    required String filename,
    required Uint8List bytes,
    String? dialogTitle,
    String mimeType = 'application/pdf',
  }) async {
    final extension = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : 'pdf';
    final selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle ?? 'Save As',
      fileName: filename,
      type: extension == 'pdf' ? FileType.custom : FileType.any,
      allowedExtensions: extension == 'pdf' ? ['pdf'] : null,
      bytes: bytes,
    );

    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return null;
    }

    var finalPath = selectedPath;
    if (extension.isNotEmpty &&
        !finalPath.toLowerCase().endsWith('.$extension')) {
      finalPath = '$finalPath.$extension';
    }

    final file = File(finalPath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<bool> openFile(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      return result.type == ResultType.done;
    } catch (_) {
      return false;
    }
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
