@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/storage/storage_web.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('stores and reads back the database', () async {
    final storage = WebDatabaseStorage();
    await storage.writeStore('{"patients":[],"users":[]}');

    expect(await WebDatabaseStorage().readStore(), '{"patients":[],"users":[]}');
  });

  test('saves a store larger than the localStorage quota', () async {
    // localStorage throws QuotaExceededError at about 5.18M characters.
    final large = '{"blob":"${'x' * 8000000}"}';
    final storage = WebDatabaseStorage();
    await storage.writeStore(large);

    expect((await WebDatabaseStorage().readStore())!.length, large.length);
  });

  test('moves data saved by earlier releases out of localStorage', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('medsentry_local_store', '{"legacy":true}');
    await prefs.setString('medsentry_backup_2026-10-01', '{"old":1}');

    // Simulate a fresh install of the new release reading existing data.
    final storage = WebDatabaseStorage();
    await storage.writeStore('');
    final migrated = await storage.readStore();

    expect(migrated, '{"legacy":true}');
    expect(prefs.getString('medsentry_local_store'), isNull);
    expect(prefs.getString('medsentry_backup_2026-10-01'), isNull);
  });

  test('keeps only the three most recent backups', () async {
    final storage = WebDatabaseStorage();
    for (var i = 0; i < 5; i++) {
      final message = await storage.createBackup('{"n":$i}');
      expect(message, contains('backup'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(await storage.readStore(), '{"n":4}');
    expect(await storage.backupKeys(), hasLength(3));
  });
}
