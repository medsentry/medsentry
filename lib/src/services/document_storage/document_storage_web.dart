import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'document_storage_interface.dart';

class WebDocumentFileStorage implements DocumentFileStorage {
  static const String _databaseName = 'medsentry_documents';
  static const String _storeName = 'files';

  Future<web.IDBDatabase> _openDatabase() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_databaseName, 1);
    request.onupgradeneeded = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      if (!database.objectStoreNames.contains(_storeName)) {
        database.createObjectStore(_storeName);
      }
    }).toJS;
    request.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.complete(request.result as web.IDBDatabase);
      }
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Unable to open document storage: '
            '${request.error?.message ?? 'IndexedDB request failed.'}',
          ),
        );
      }
    }).toJS;
    request.onblocked = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Document storage is blocked by another browser connection.',
          ),
        );
      }
    }).toJS;
    return completer.future;
  }

  Future<void> _waitForTransaction(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    transaction.oncomplete = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    transaction.onabort = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Document storage transaction failed: '
            '${transaction.error?.message ?? 'transaction aborted.'}',
          ),
        );
      }
    }).toJS;
    transaction.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Document storage transaction failed: '
            '${transaction.error?.message ?? 'IndexedDB request failed.'}',
          ),
        );
      }
    }).toJS;
    return completer.future;
  }

  @override
  Future<String> saveFile({
    required String documentId,
    required String patientId,
    required List<int> encryptedBytes,
    required String fileName,
  }) async {
    final database = await _openDatabase();
    try {
      final transaction = database.transaction(
        _storeName.toJS,
        'readwrite',
      );
      final completed = _waitForTransaction(transaction);
      final virtualPath = 'web://documents/$patientId/$documentId';
      final encoded = base64Encode(encryptedBytes);
      transaction.objectStore(_storeName).put(
        encoded.toJS,
        virtualPath.toJS,
      );
      await completed;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('medsentry_doc_$virtualPath');
      return virtualPath;
    } finally {
      database.close();
    }
  }

  @override
  Future<List<int>?> readFile(String filePath) async {
    final database = await _openDatabase();
    try {
      final transaction = database.transaction(
        _storeName.toJS,
        'readonly',
      );
      final request = transaction.objectStore(_storeName).get(filePath.toJS);
      final encoded = await _readString(request);
      if (encoded == null) {
        final prefs = await SharedPreferences.getInstance();
        final legacy = prefs.getString('medsentry_doc_$filePath');
        if (legacy == null) return null;
        final transaction = database.transaction(
          _storeName.toJS,
          'readwrite',
        );
        final completed = _waitForTransaction(transaction);
        transaction.objectStore(_storeName).put(legacy.toJS, filePath.toJS);
        await completed;
        await prefs.remove('medsentry_doc_$filePath');
        return base64Decode(legacy);
      }
      return base64Decode(encoded);
    } finally {
      database.close();
    }
  }

  Future<String?> _readString(web.IDBRequest request) {
    final completer = Completer<String?>();
    request.onsuccess = ((web.Event _) {
      final result = request.result;
      if (result == null) {
        completer.complete(null);
      } else {
        final value = result.dartify();
        if (value is String) {
          completer.complete(value);
        } else {
          completer.completeError(
            StateError('Document storage contains an invalid record.'),
          );
        }
      }
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Unable to read document: '
            '${request.error?.message ?? 'IndexedDB request failed.'}',
          ),
        );
      }
    }).toJS;
    return completer.future;
  }

  @override
  Future<void> openFile(
    String filePath, {
    List<int>? decryptedBytes,
    String? fileName,
  }) async {
    final bytes = decryptedBytes ?? await readFile(filePath);
    if (bytes == null) {
      throw StateError('The document is no longer available in this browser.');
    }

    final safeName = _safeFileName(fileName, filePath);
    final extension = safeName.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
    final blob = web.Blob(
      [Uint8List.fromList(bytes).toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final objectUrl = web.URL.createObjectURL(blob);
    final link = web.HTMLAnchorElement()
      ..href = objectUrl
      ..download = safeName
      ..style.display = 'none';
    final body = web.document.body;
    if (body == null) {
      web.URL.revokeObjectURL(objectUrl);
      throw StateError('Cannot download the document because the page is unavailable.');
    }

    body.append(link);
    link.click();
    link.remove();
    unawaited(
      Future<void>.delayed(
        const Duration(seconds: 30),
        () => web.URL.revokeObjectURL(objectUrl),
      ),
    );
  }

  @override
  Future<void> deleteFile(String filePath) async {
    final database = await _openDatabase();
    try {
      final transaction = database.transaction(
        _storeName.toJS,
        'readwrite',
      );
      final completed = _waitForTransaction(transaction);
      transaction.objectStore(_storeName).delete(filePath.toJS);
      await completed;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('medsentry_doc_$filePath');
    } finally {
      database.close();
    }
  }

  String _safeFileName(String? fileName, String filePath) {
    final name = (fileName?.trim().isNotEmpty == true)
        ? fileName!.trim()
        : filePath.split('/').last;
    final safeName = name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'^\.+'), '')
        .replaceAll(RegExp(r'\.+$'), '');
    return safeName.isEmpty ? 'document' : safeName;
  }
}

DocumentFileStorage createDocumentFileStorage() => WebDocumentFileStorage();
