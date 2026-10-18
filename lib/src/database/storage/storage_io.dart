import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'storage_interface.dart';

class IoDatabaseStorage implements DatabaseStorage {
  File? _storeFile;

  @override
  void setCustomStoreFile(dynamic file) {
    if (file is File) {
      _storeFile = file;
    }
  }

  void useStoreFileForTesting(File file) {
    _storeFile = file;
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

  @override
  Future<String?> readStore() async {
    final file = await _resolveStoreFile();
    if (await file.exists()) {
      final raw = await file.readAsString();
      if (raw.trim().isNotEmpty) return raw;
    }

    // Fallback recovery if primary store file was interrupted
    final tempFile = File('${file.path}.tmp');
    if (await tempFile.exists()) {
      final raw = await tempFile.readAsString();
      if (raw.trim().isNotEmpty) {
        try {
          await tempFile.copy(file.path);
        } catch (_) {}
        return raw;
      }
    }

    return null;
  }

  @override
  Future<void> writeStore(String jsonString) async {
    final file = await _resolveStoreFile();
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(jsonString, flush: true);
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
  Future<String> createBackup(String jsonString) async {
    await writeStore(jsonString);
    final source = await _resolveStoreFile();
    final documentsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(
      p.join(documentsDir.path, 'MedSentry', 'Backups'),
    );
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupFile = File(
      p.join(backupDir.path, 'medsentry_backup_$timestamp.json'),
    );
    await source.copy(backupFile.path);
    return backupFile.path;
  }
}

DatabaseStorage createDatabaseStorage() => IoDatabaseStorage();
