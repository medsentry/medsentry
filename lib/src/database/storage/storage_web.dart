import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'storage_interface.dart';

/// Stores the local database in IndexedDB.
///
/// localStorage was used before, but browsers cap it at about 5 million
/// characters per site; a busy RHU reached that within weeks, after which
/// every save failed. IndexedDB quotas scale with free disk space.
class WebDatabaseStorage implements DatabaseStorage {
  static const String _databaseName = 'medsentry_database';
  static const String _storeName = 'store';
  static const String _mainKey = 'main';
  static const String _backupKeyPrefix = 'backup:';
  static const int _backupsKept = 3;

  // Keys used by the localStorage-based storage of earlier releases.
  static const String _legacyStorageKey = 'medsentry_local_store';
  static const String _legacyBackupKeyPrefix = 'medsentry_backup_';

  Future<web.IDBDatabase>? _database;

  @override
  void setCustomStoreFile(dynamic file) {}

  Future<web.IDBDatabase> _open() {
    return _database ??= () {
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
              'Unable to open local database: '
              '${request.error?.message ?? 'IndexedDB request failed.'}',
            ),
          );
        }
      }).toJS;
      request.onblocked = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('Local database is blocked by another browser tab.'),
          );
        }
      }).toJS;
      return completer.future.catchError((Object error) {
        _database = null;
        throw error;
      });
    }();
  }

  Future<void> _complete(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    void fail() {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Local database write failed: '
            '${transaction.error?.message ?? 'transaction aborted.'}',
          ),
        );
      }
    }

    transaction.oncomplete = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    transaction.onabort = ((web.Event _) => fail()).toJS;
    transaction.onerror = ((web.Event _) => fail()).toJS;
    return completer.future;
  }

  Future<String?> _get(String key) async {
    final database = await _open();
    final request = database
        .transaction(_storeName.toJS, 'readonly')
        .objectStore(_storeName)
        .get(key.toJS);
    final completer = Completer<String?>();
    request.onsuccess = ((web.Event _) {
      final value = request.result?.dartify();
      completer.complete(value is String ? value : null);
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Unable to read local database: '
            '${request.error?.message ?? 'IndexedDB request failed.'}',
          ),
        );
      }
    }).toJS;
    return completer.future;
  }

  @visibleForTesting
  Future<List<String>> backupKeys() async =>
      (await _keys()).where((key) => key.startsWith(_backupKeyPrefix)).toList();

  Future<List<String>> _keys() async {
    final database = await _open();
    final request = database
        .transaction(_storeName.toJS, 'readonly')
        .objectStore(_storeName)
        .getAllKeys();
    final completer = Completer<List<String>>();
    request.onsuccess = ((web.Event _) {
      final keys = request.result?.dartify();
      completer.complete(
        keys is List ? keys.whereType<String>().toList() : const [],
      );
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) completer.complete(const []);
    }).toJS;
    return completer.future;
  }

  Future<void> _write(
    Map<String, String> puts, {
    List<String> deletes = const [],
  }) async {
    final database = await _open();
    final transaction = database.transaction(_storeName.toJS, 'readwrite');
    final done = _complete(transaction);
    final store = transaction.objectStore(_storeName);
    for (final entry in puts.entries) {
      store.put(entry.value.toJS, entry.key.toJS);
    }
    for (final key in deletes) {
      store.delete(key.toJS);
    }
    await done;
  }

  /// Moves data saved by earlier releases out of localStorage, where it was
  /// also readable as plain text, and frees the space it used.
  Future<String?> _migrateLegacyStore() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyStorageKey);
    final legacyBackupKeys =
        prefs
            .getKeys()
            .where((key) => key.startsWith(_legacyBackupKeyPrefix))
            .toList()
          ..sort();
    if (legacy == null && legacyBackupKeys.isEmpty) return null;

    final puts = <String, String>{};
    if (legacy != null && legacy.trim().isNotEmpty) puts[_mainKey] = legacy;
    for (final key in legacyBackupKeys.reversed.take(_backupsKept)) {
      final value = prefs.getString(key);
      if (value != null) {
        puts['$_backupKeyPrefix${key.substring(_legacyBackupKeyPrefix.length)}'] =
            value;
      }
    }
    await _write(puts);
    await prefs.remove(_legacyStorageKey);
    for (final key in legacyBackupKeys) {
      await prefs.remove(key);
    }
    return puts[_mainKey];
  }

  @override
  Future<String?> readStore() async {
    final stored = await _get(_mainKey);
    final raw = stored == null || stored.trim().isEmpty
        ? await _migrateLegacyStore()
        : stored;
    if (raw == null || raw.trim().isEmpty) return null;
    return raw;
  }

  @override
  Future<void> writeStore(String jsonString) {
    return _write({_mainKey: jsonString});
  }

  @override
  Future<String> createBackup(String jsonString, {String? passphrase}) async {
    // Kept inside this browser's own storage, never written as a file, so
    // there is nothing for a passphrase to protect.
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupKey = '$_backupKeyPrefix$timestamp';
    final existing =
        (await _keys())
            .where((key) => key.startsWith(_backupKeyPrefix))
            .toList()
          ..sort();
    final stale = existing.length >= _backupsKept
        ? existing.sublist(0, existing.length - _backupsKept + 1)
        : const <String>[];
    await _write({_mainKey: jsonString, backupKey: jsonString}, deletes: stale);
    return 'Browser local backup created: $backupKey '
        '(the $_backupsKept most recent backups are kept)';
  }
}

DatabaseStorage createDatabaseStorage() => WebDatabaseStorage();
