import 'dart:math';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:encrypt/encrypt.dart' as encrypt;
import '../models/document.dart';
import 'document_storage/document_storage.dart';

class DocumentService {
  static final DocumentFileStorage _fileStorage = createDocumentFileStorage();
  static const int maxFileSizeBytes = 10 * 1024 * 1024;
  static const Set<String> allowedExtensions = {'pdf', 'jpg', 'jpeg', 'png'};
  static const String _encryptionKeyName = 'medsentry.document_key';
  static const List<int> _encryptedHeader = [77, 83, 69, 78, 67, 49]; // MSENC1
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Pick a file using file_picker
  static Future<DocumentPickerResult?> pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions.toList(),
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;

      final picked = DocumentPickerResult(
        name: file.name,
        path: kIsWeb ? null : file.path,
        bytes: file.bytes,
        extension: file.extension?.toLowerCase() ?? 'unknown',
        size: file.size,
      );
      validatePickedDocument(picked);
      return picked;
    } catch (e) {
      throw Exception('Failed to pick document: $e');
    }
  }

  /// Pick an image using file_selector (for Windows desktop)
  static Future<DocumentPickerResult?> pickImage() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'images',
        extensions: ['jpg', 'jpeg', 'png'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) {
        return null;
      }

      final bytes = await file.readAsBytes();
      final fileName = file.name;
      final extension = p
          .extension(fileName)
          .toLowerCase()
          .replaceFirst('.', '');

      final picked = DocumentPickerResult(
        name: fileName,
        path: kIsWeb ? null : file.path,
        bytes: bytes,
        extension: extension,
        size: bytes.length,
      );
      validatePickedDocument(picked);
      return picked;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  static void validatePickedDocument(DocumentPickerResult document) {
    final extension = document.extension.toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw DocumentValidationException(
        'Only PDF, JPG, JPEG, and PNG files can be uploaded.',
      );
    }

    if (document.size <= 0) {
      throw DocumentValidationException('The selected file is empty.');
    }

    if (document.size > maxFileSizeBytes) {
      throw DocumentValidationException(
        'File must be ${formatFileSize(maxFileSizeBytes)} or smaller.',
      );
    }

    if (document.bytes == null && document.path == null) {
      throw DocumentValidationException(
        'The selected file could not be read. Please choose another file.',
      );
    }
  }

  /// Save document to local storage
  static Future<String> saveDocument({
    required String documentId,
    required String patientId,
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      final extension = p
          .extension(fileName)
          .toLowerCase()
          .replaceFirst('.', '');
      if (!allowedExtensions.contains(extension)) {
        throw DocumentValidationException(
          'Only PDF, JPG, JPEG, and PNG files can be saved.',
        );
      }
      if (bytes.isEmpty) {
        throw DocumentValidationException('The selected file is empty.');
      }
      if (bytes.length > maxFileSizeBytes) {
        throw DocumentValidationException(
          'File must be ${formatFileSize(maxFileSizeBytes)} or smaller.',
        );
      }

      final encryptedBytes = await _encryptBytes(bytes);
      return await _fileStorage.saveFile(
        documentId: documentId,
        patientId: patientId,
        encryptedBytes: encryptedBytes,
        fileName: fileName,
      );
    } catch (e) {
      throw Exception('Failed to save document: $e');
    }
  }

  /// Open a document using the default application
  static Future<void> openDocument(String filePath) async {
    try {
      final rawBytes = await _fileStorage.readFile(filePath);
      List<int>? decryptedBytes;
      if (rawBytes != null && _isEncrypted(rawBytes)) {
        decryptedBytes = await _decryptBytes(rawBytes);
      }
      await _fileStorage.openFile(filePath, decryptedBytes: decryptedBytes);
    } catch (e) {
      throw Exception('Failed to open document: $e');
    }
  }

  /// Delete a document from local storage
  static Future<void> deleteDocument(String filePath) async {
    try {
      await _fileStorage.deleteFile(filePath);
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  /// Get file size in human-readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get document type from file extension
  static DocumentType getDocumentType(String extension) {
    final ext = extension.toLowerCase();
    return switch (ext) {
      'pdf' => DocumentType.labResult,
      'jpg' || 'jpeg' || 'png' => DocumentType.xRay,
      _ => DocumentType.other,
    };
  }

  static Future<List<int>> _encryptBytes(List<int> bytes) async {
    final key = await _documentKey();
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);
    return [..._encryptedHeader, ...iv.bytes, ...encrypted.bytes];
  }

  static Future<List<int>> _decryptBytes(List<int> bytes) async {
    if (!_isEncrypted(bytes)) return bytes;
    final key = await _documentKey();
    final iv = encrypt.IV(
      Uint8List.fromList(
        bytes.sublist(_encryptedHeader.length, _encryptedHeader.length + 16),
      ),
    );
    final encryptedBytes = bytes.sublist(_encryptedHeader.length + 16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.decryptBytes(
      encrypt.Encrypted(Uint8List.fromList(encryptedBytes)),
      iv: iv,
    );
  }

  static bool _isEncrypted(List<int> bytes) {
    if (bytes.length < _encryptedHeader.length + 16) return false;
    for (var i = 0; i < _encryptedHeader.length; i++) {
      if (bytes[i] != _encryptedHeader[i]) return false;
    }
    return true;
  }

  static Future<encrypt.Key> _documentKey() async {
    final existing = await _secureStorage.read(key: _encryptionKeyName);
    if (existing != null) {
      return encrypt.Key(Uint8List.fromList(base64Decode(existing)));
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    await _secureStorage.write(
      key: _encryptionKeyName,
      value: base64Encode(bytes),
    );
    return encrypt.Key(Uint8List.fromList(bytes));
  }
}

class DocumentValidationException implements Exception {
  final String message;

  const DocumentValidationException(this.message);

  @override
  String toString() => message;
}

class DocumentPickerResult {
  final String name;
  final String? path;
  final List<int>? bytes;
  final String extension;
  final int size;

  DocumentPickerResult({
    required this.name,
    this.path,
    this.bytes,
    required this.extension,
    required this.size,
  });

  Future<List<int>> getBytes() async {
    if (bytes != null) return bytes!;
    if (path != null) {
      final fileBytes = await DocumentService._fileStorage.readFile(path!);
      if (fileBytes != null) return fileBytes;
    }
    throw StateError('No bytes or valid file path available.');
  }
}
