import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'document_storage_interface.dart';

class WebDocumentFileStorage implements DocumentFileStorage {
  static const String _keyPrefix = 'medsentry_doc_';

  @override
  Future<String> saveFile({
    required String documentId,
    required String patientId,
    required List<int> encryptedBytes,
    required String fileName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final virtualPath = 'web://documents/$patientId/$documentId';
    await prefs.setString(
      '$_keyPrefix$virtualPath',
      base64Encode(encryptedBytes),
    );
    return virtualPath;
  }

  @override
  Future<List<int>?> readFile(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('$_keyPrefix$filePath');
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  @override
  Future<void> openFile(
    String filePath, {
    List<int>? decryptedBytes,
    String? fileName,
  }) async {
    // In web browsers, documents are accessed directly in memory or downloaded
  }

  @override
  Future<void> deleteFile(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$filePath');
  }
}

DocumentFileStorage createDocumentFileStorage() => WebDocumentFileStorage();
