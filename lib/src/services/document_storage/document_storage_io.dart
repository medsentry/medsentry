import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'document_storage_interface.dart';

class IoDocumentFileStorage implements DocumentFileStorage {
  @override
  Future<String> saveFile({
    required String documentId,
    required String patientId,
    required List<int> encryptedBytes,
    required String fileName,
  }) async {
    final extension = p.extension(fileName).toLowerCase().replaceFirst('.', '');

    final appDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(p.join(appDir.path, 'medsentry_documents'));

    if (!await documentsDir.exists()) {
      await documentsDir.create(recursive: true);
    }

    final patientDir = Directory(p.join(documentsDir.path, patientId));
    if (!await patientDir.exists()) {
      await patientDir.create(recursive: true);
    }

    final savedFileName = '$documentId.$extension';
    final filePath = p.join(patientDir.path, savedFileName);

    final file = File(filePath);
    await file.writeAsBytes(encryptedBytes, flush: true);

    return filePath;
  }

  @override
  Future<List<int>?> readFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  @override
  Future<void> openFile(
    String filePath, {
    List<int>? decryptedBytes,
    String? fileName,
  }) async {
    final file = File(filePath);
    if (!await file.exists() && decryptedBytes == null) {
      throw Exception('The file no longer exists on this device.');
    }

    String openPath = filePath;
    if (decryptedBytes != null) {
      final tempDir = await getTemporaryDirectory();
      final targetName = fileName ?? p.basename(filePath);
      final tempFile = File(p.join(tempDir.path, targetName));
      await tempFile.writeAsBytes(decryptedBytes, flush: true);
      openPath = tempFile.path;
    }

    final result = await OpenFilex.open(openPath);
    if (result.type != ResultType.done) {
      throw Exception('Failed to open document: ${result.message}');
    }
  }

  @override
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

DocumentFileStorage createDocumentFileStorage() => IoDocumentFileStorage();
