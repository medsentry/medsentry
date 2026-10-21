import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'storage_interface.dart';
import 'store_cipher.dart';

/// Holds the key that encrypts the database file on this device.
abstract class DeviceStoreKey {
  /// The stored key, or null if none was ever created. Throws when the key
  /// store cannot be read, which is not the same as the key being absent.
  Future<Uint8List?> read();

  Future<void> write(Uint8List key);
}

/// Keeps the key in the operating system's protected store (DPAPI on
/// Windows, Keychain on macOS), readable only by the signed-in OS account.
class SecureDeviceStoreKey implements DeviceStoreKey {
  static const String _keyName = 'medsentry.database_key';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<Uint8List?> read() async {
    final value = await _storage.read(key: _keyName);
    return value == null ? null : base64Decode(value);
  }

  @override
  Future<void> write(Uint8List key) =>
      _storage.write(key: _keyName, value: base64Encode(key));
}

class IoDatabaseStorage implements DatabaseStorage {
  IoDatabaseStorage({DeviceStoreKey? deviceKey, File? storeFile})
    : _deviceKey = deviceKey ?? SecureDeviceStoreKey(),
      _storeFile = storeFile,
      _encrypt = true;

  final DeviceStoreKey _deviceKey;
  File? _storeFile;
  // Files injected by tests stay plain JSON so tests can inspect them.
  bool _encrypt;
  Future<Uint8List?>? _keyFuture;
  Future<Uint8List>? _createKeyFuture;
  // Saves share one .tmp file, so each waits for the previous one: two at
  // once raced on it and the second copy failed (errno 183 on Windows).
  Future<void> _pendingWrite = Future.value();

  @override
  void setCustomStoreFile(dynamic file) {
    if (file is File) {
      _storeFile = file;
      _encrypt = false;
    }
  }

  void useStoreFileForTesting(File file) {
    _storeFile = file;
    _encrypt = false;
  }

  Future<File> _resolveStoreFile() async {
    if (_storeFile != null) return _storeFile!;

    Directory baseDir;
    try {
      baseDir = await getApplicationSupportDirectory();
    } catch (_) {
      baseDir = Directory(p.join(Directory.current.path, '.medsentry_data'));
    }

    final dataDir = Directory(p.join(baseDir.path, 'medsentry'));
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }

    _storeFile = File(p.join(dataDir.path, 'local_store.json'));
    return _storeFile!;
  }

  // Memoized: two concurrent first saves would otherwise each create and
  // store a different key, leaving the file sealed with the lost one.
  Future<Uint8List?> _key({required bool create}) async {
    final existing = await (_keyFuture ??= _deviceKey.read().catchError((
      Object error,
    ) {
      _keyFuture = null;
      throw error;
    }));
    if (existing != null || !create) return existing;
    return _createKeyFuture ??= () async {
      final created = StoreCipher.randomKey();
      await _deviceKey.write(created);
      _keyFuture = Future.value(created);
      return created;
    }().catchError((Object error) {
      _createKeyFuture = null;
      throw error;
    });
  }

  @override
  Future<String?> readStore() async {
    final file = await _resolveStoreFile();
    final tempFile = File('${file.path}.tmp');

    final primary = await _readFile(file);
    if (primary != null) {
      final opened = await _open(primary);
      if (opened != null) return opened;
    }

    // Fallback recovery if primary store file was interrupted or damaged.
    final temp = await _readFile(tempFile);
    if (temp != null) {
      final opened = await _open(temp);
      if (opened != null) {
        try {
          await tempFile.copy(file.path);
        } catch (_) {}
        return opened;
      }
    }

    if (primary != null || temp != null) {
      // The data is sealed with a key this device no longer has, or is
      // damaged. Set it aside instead of overwriting it, and start empty so
      // the clinic can keep working; synced records download again.
      await _quarantine(file);
      await _quarantine(tempFile);
    }
    return null;
  }

  Future<Uint8List?> _readFile(File file) async {
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  }

  /// Returns the JSON in [bytes], or null if it cannot be decrypted.
  Future<String?> _open(Uint8List bytes) async {
    if (!StoreCipher.hasMagic(bytes, StoreCipher.deviceStoreMagic)) {
      // Plain JSON from earlier releases; the next save encrypts it.
      final raw = utf8.decode(bytes, allowMalformed: true);
      return raw.trim().isEmpty ? null : raw;
    }
    // A key store that cannot be read throws here and nothing is set aside:
    // the key may come back on the next attempt.
    final key = await _key(create: false);
    if (key == null) {
      debugPrint('Local database is encrypted but this device has no key.');
      return null;
    }
    try {
      return await Isolate.run(
        () => utf8.decode(
          StoreCipher.open(key, bytes, magic: StoreCipher.deviceStoreMagic),
        ),
      );
    } on StoreCipherException catch (error) {
      debugPrint('Local database could not be opened: $error');
      return null;
    }
  }

  Future<void> _quarantine(File file) async {
    if (!await file.exists()) return;
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final target = '${file.path}.unreadable-$stamp';
    try {
      await file.rename(target);
      debugPrint('Unreadable local database moved to $target');
    } catch (error) {
      debugPrint('Unable to set aside unreadable local database: $error');
    }
  }

  Future<List<int>> _encode(String jsonString) async {
    if (!_encrypt) return utf8.encode(jsonString);
    final Uint8List? key;
    try {
      key = await _key(create: true);
    } catch (error) {
      // Refusing to save would stop the clinic from recording patients, so
      // a missing OS key store falls back to the unencrypted format.
      debugPrint('Secure key storage unavailable; saving unencrypted: $error');
      return utf8.encode(jsonString);
    }
    return Isolate.run(
      () => StoreCipher.seal(
        key!,
        utf8.encode(jsonString),
        magic: StoreCipher.deviceStoreMagic,
      ),
    );
  }

  @override
  Future<void> writeStore(String jsonString) {
    final write = _pendingWrite.then((_) => _writeStoreNow(jsonString));
    // A failed save is reported to its caller and does not block the next.
    _pendingWrite = write.catchError((_) {});
    return write;
  }

  Future<void> _writeStoreNow(String jsonString) async {
    final file = await _resolveStoreFile();
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsBytes(await _encode(jsonString), flush: true);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    try {
      await tempFile.rename(file.path);
    } catch (_) {
      // Fallback for Windows cross-volume or locked rename
      await tempFile.copy(file.path);
      try {
        await tempFile.delete();
      } catch (_) {}
    }
  }

  @override
  Future<String> createBackup(String jsonString, {String? passphrase}) async {
    // Backups land in Documents, which is often synced to OneDrive or copied
    // to USB drives, so they are never written unencrypted.
    if (passphrase == null) {
      throw ArgumentError('A passphrase is required to create a backup');
    }
    final sealed = await Isolate.run(
      () => BackupCipher.seal(jsonString, passphrase),
    );
    await writeStore(jsonString);
    final documentsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(
      p.join(documentsDir.path, 'MedSentry', 'Backups'),
    );
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupFile = File(
      p.join(
        backupDir.path,
        'medsentry_backup_$timestamp.${BackupCipher.fileExtension}',
      ),
    );
    await backupFile.writeAsBytes(sealed, flush: true);
    return backupFile.path;
  }
}

DatabaseStorage createDatabaseStorage() => IoDatabaseStorage();
