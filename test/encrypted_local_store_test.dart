import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/database/storage/storage_io.dart';
import 'package:medsentry/src/database/storage/store_cipher.dart';
import 'package:medsentry/src/models/models.dart';

class _MemoryKey implements DeviceStoreKey {
  Uint8List? key;
  int writes = 0;
  Object? readError;

  @override
  Future<Uint8List?> read() async {
    if (readError != null) throw readError!;
    // Yield so concurrent callers interleave as they would on a real store.
    await Future<void>.delayed(Duration.zero);
    return key;
  }

  @override
  Future<void> write(Uint8List value) async {
    writes++;
    key = value;
  }
}

void main() {
  late Directory dir;
  late File storeFile;
  late _MemoryKey deviceKey;

  const patientJson = '{"patients":[{"first_name":"Juana Dela Cruz"}],"users":[]}';

  IoDatabaseStorage storage() =>
      IoDatabaseStorage(deviceKey: deviceKey, storeFile: storeFile);

  List<File> quarantined() => dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.contains('.unreadable-'))
      .toList();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('encrypted_store');
    storeFile = File('${dir.path}/local_store.json');
    deviceKey = _MemoryKey();
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('device store', () {
    test('patient data is not readable in the file on disk', () async {
      await storage().writeStore(patientJson);

      final bytes = await storeFile.readAsBytes();
      expect(StoreCipher.hasMagic(bytes, StoreCipher.deviceStoreMagic), isTrue);
      expect(latin1.decode(bytes), isNot(contains('Juana')));
      expect(await storage().readStore(), patientJson);
    });

    test('a plain store from an earlier release is read, then encrypted', () async {
      await storeFile.writeAsString(patientJson);
      final store = storage();

      expect(await store.readStore(), patientJson);
      await store.writeStore(patientJson);

      expect(latin1.decode(await storeFile.readAsBytes()), isNot(contains('Juana')));
      expect(await storage().readStore(), patientJson);
    });

    test('an altered file is set aside, not decrypted or deleted', () async {
      await storage().writeStore(patientJson);
      final bytes = await storeFile.readAsBytes();
      bytes[bytes.length ~/ 2] ^= 0x01;
      await storeFile.writeAsBytes(bytes);

      expect(await storage().readStore(), isNull);
      expect(await storeFile.exists(), isFalse);
      expect(quarantined(), hasLength(1));
      expect(await quarantined().single.readAsBytes(), bytes);
    });

    test('a lost key sets the file aside instead of overwriting it', () async {
      await storage().writeStore(patientJson);
      deviceKey.key = null;

      expect(await storage().readStore(), isNull);
      expect(quarantined(), hasLength(1));
    });

    test('an unreadable key store leaves the file untouched', () async {
      await storage().writeStore(patientJson);
      deviceKey.readError = StateError('key store locked');

      await expectLater(storage().readStore(), throwsStateError);
      expect(await storeFile.exists(), isTrue);
      expect(quarantined(), isEmpty);

      deviceKey.readError = null;
      expect(await storage().readStore(), patientJson);
    });

    test('the copy left by an interrupted save is recovered', () async {
      await storage().writeStore(patientJson);
      await storeFile.rename('${storeFile.path}.tmp');

      expect(await storage().readStore(), patientJson);
      expect(await storeFile.exists(), isTrue);
    });

    test('concurrent first saves create a single key', () async {
      final store = storage();

      await Future.wait([
        store.writeStore(patientJson),
        store.writeStore(patientJson),
      ]);

      expect(deviceKey.writes, 1);
      expect(await storage().readStore(), patientJson);
    });

    test('a key store that cannot be written still saves the data', () async {
      final store = IoDatabaseStorage(
        deviceKey: _UnwritableKey(),
        storeFile: storeFile,
      );

      await store.writeStore(patientJson);

      expect(await storeFile.readAsString(), patientJson);
    });
  });

  group('backups', () {
    test('a backup opens with its passphrase on another device', () {
      final sealed = BackupCipher.seal(patientJson, 'correct horse', iterations: 2000);

      expect(latin1.decode(sealed), isNot(contains('Juana')));
      expect(BackupCipher.open(sealed, 'correct horse'), patientJson);
    });

    test('a wrong passphrase is rejected', () {
      final sealed = BackupCipher.seal(patientJson, 'correct horse', iterations: 2000);

      expect(
        () => BackupCipher.open(sealed, 'wrong horse'),
        throwsA(isA<StoreCipherException>()),
      );
    });

    test('a changed iteration count is rejected', () {
      final sealed = BackupCipher.seal(patientJson, 'correct horse', iterations: 2000);
      // The iteration count sits right after the 6-byte magic and 16-byte salt.
      sealed[6 + 16 + 3] ^= 0x01;

      expect(
        () => BackupCipher.open(sealed, 'correct horse'),
        throwsA(isA<StoreCipherException>()),
      );
    });

    test('a short passphrase is refused', () {
      expect(
        () => BackupCipher.seal(patientJson, 'short'),
        throwsArgumentError,
      );
    });

    test('desktop backups are never written without a passphrase', () async {
      await expectLater(
        storage().createBackup(patientJson),
        throwsArgumentError,
      );
    });

    test('the database restores encrypted and plain backups', () async {
      final db = SimpleDatabase();
      await db.useStoreFileForTesting(File('${dir.path}/restore.json'));
      final backup = jsonEncode({
        'patients': [
          Patient(
            id: 'p1',
            clinicId: 'c1',
            firstName: 'Juana',
            lastName: 'Dela Cruz',
          ).toJson(),
        ],
        'users': <Object>[],
      });

      final sealed = BackupCipher.seal(backup, 'correct horse', iterations: 2000);
      expect(SimpleDatabase.isEncryptedBackup(sealed), isTrue);
      await expectLater(db.restoreFromBackup(sealed), throwsArgumentError);
      await db.restoreFromBackup(sealed, passphrase: 'correct horse');
      expect((await db.getPatientById('p1'))?.firstName, 'Juana');

      await db.restoreFromBackup(
        Uint8List.fromList(utf8.encode(backup.replaceAll('Juana', 'Maria'))),
      );
      expect((await db.getPatientById('p1'))?.firstName, 'Maria');
    });
  });
}

class _UnwritableKey implements DeviceStoreKey {
  @override
  Future<Uint8List?> read() async => null;

  @override
  Future<void> write(Uint8List key) async =>
      throw StateError('no key store on this machine');
}
