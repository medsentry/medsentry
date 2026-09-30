import 'package:shared_preferences/shared_preferences.dart';

import 'storage_interface.dart';

class WebDatabaseStorage implements DatabaseStorage {
  static const String _storageKey = 'medsentry_local_store';
  static const String _backupKeyPrefix = 'medsentry_backup_';

  @override
  void setCustomStoreFile(dynamic file) {}

  @override
  Future<String?> readStore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw;
  }

  @override
  Future<void> writeStore(String jsonString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonString);
  }

  @override
  Future<String> createBackup(String jsonString) async {
    await writeStore(jsonString);
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupKey = '$_backupKeyPrefix$timestamp';
    await prefs.setString(backupKey, jsonString);
    return 'Browser local backup created: $backupKey';
  }
}

DatabaseStorage createDatabaseStorage() => WebDatabaseStorage();
