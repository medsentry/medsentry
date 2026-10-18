import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/audit_log.dart';
import 'package:medsentry/src/models/clinic.dart';
import 'package:medsentry/src/models/patient.dart';
import 'package:medsentry/src/models/user.dart';

void main() {
  late SimpleDatabase db;
  late Directory tempDir;
  late File storeFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('medsentry_sync_e2e_test');
    storeFile = File('${tempDir.path}/test_store.json');
    db = SimpleDatabase();
    await db.useStoreFileForTesting(storeFile);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Sync End-to-End & Database Hardening Tests', () {
    test('Persistence ordering: disk write completes before change notification', () async {
      final completer = Completer<void>();
      var fileExistedAtNotification = false;
      var fileSizeAtNotification = 0;

      final sub = db.changes.listen((_) {
        fileExistedAtNotification = storeFile.existsSync();
        if (fileExistedAtNotification) {
          fileSizeAtNotification = storeFile.lengthSync();
        }
        if (!completer.isCompleted) completer.complete();
      });

      final patient = Patient(
        id: 'patient-persist-1',
        clinicId: 'clinic-1',
        firstName: 'Maria',
        lastName: 'Santos',
        createdAt: DateTime.now(),
        syncStatus: 1,
      );

      await db.insertPatient(patient);
      await completer.future.timeout(const Duration(seconds: 2));

      expect(fileExistedAtNotification, isTrue);
      expect(fileSizeAtNotification, greaterThan(0));

      await sub.cancel();
    });

    test('Concurrent saves are serialized without race conditions or data loss', () async {
      final futures = <Future<void>>[];
      for (var i = 0; i < 10; i++) {
        futures.add(
          db.insertPatient(
            Patient(
              id: 'patient-concurrent-$i',
              clinicId: 'clinic-1',
              firstName: 'Test$i',
              lastName: 'User$i',
              createdAt: DateTime.now(),
              syncStatus: 1,
            ),
          ),
        );
      }

      await Future.wait(futures);

      final allPatients = await db.getAllPatients();
      expect(allPatients.length, 10);

      // Verify the durable disk file contains all 10 records
      expect(storeFile.existsSync(), isTrue);
      final raw = storeFile.readAsStringSync();
      for (var i = 0; i < 10; i++) {
        expect(raw.contains('patient-concurrent-$i'), isTrue);
      }
    });

    test('Audit logs: unsynced logs are accounted in pending sync and marked synced', () async {
      expect(await db.getPendingSyncCount(), 0);

      final log1 = AuditLog(
        id: 'audit-1',
        userId: 'user-1',
        action: AuditAction.create,
        entityType: 'patient',
        timestamp: DateTime.now(),
        isSynced: false,
      );

      await db.insertAuditLog(log1);

      // Verify unsynced audit logs are counted in pending sync count
      expect(await db.getPendingSyncCount(), 1);
      final unsynced = await db.getUnsyncedAuditLogs();
      expect(unsynced.length, 1);
      expect(unsynced.first.id, 'audit-1');

      // Mark as synced
      await db.markAuditLogAsSynced('audit-1');

      expect(await db.getPendingSyncCount(), 0);
      expect(await db.getUnsyncedAuditLogs(), isEmpty);
      final logs = await db.getAllAuditLogs();
      expect(logs.first.isSynced, isTrue);
      expect(logs.first.syncStatus, 0);
    });

    test('Clinic deletion records a tombstone in pending sync deletes', () async {
      final clinic = Clinic(
        id: 'clinic-to-delete',
        name: 'Temporary RHU',
        code: 'RHU-TEMP',
        status: 'active',
      );

      await db.insertClinic(clinic);
      expect((await db.getAllClinics()).any((c) => c.id == 'clinic-to-delete'), isTrue);

      await db.deleteClinic('clinic-to-delete');
      expect((await db.getAllClinics()).any((c) => c.id == 'clinic-to-delete'), isFalse);

      final pendingDeletes = await db.getPendingSyncDeletes();
      expect(
        pendingDeletes.any((d) => d['table'] == 'clinics' && d['record_id'] == 'clinic-to-delete'),
        isTrue,
      );

      // Complete sync delete
      await db.markSyncDeleteComplete('clinics', 'clinic-to-delete');
      final remainingDeletes = await db.getPendingSyncDeletes();
      expect(
        remainingDeletes.any((d) => d['table'] == 'clinics' && d['record_id'] == 'clinic-to-delete'),
        isFalse,
      );
    });

    test('User sync status: deactivating user offline marks user dirty (syncStatus = 2)', () async {
      final user = User(
        id: 'user-deactivate-test',
        email: 'nurse@rhu.gov.ph',
        firstName: 'Ana',
        lastName: 'Reyes',
        role: UserRole.staff,
        isActive: true,
        pinEnabled: false,
        createdAt: DateTime.now(),
        syncStatus: 0,
      );

      await db.insertUser(user);
      expect(await db.getPendingSyncCount(), 0);

      await db.deactivateUser('user-deactivate-test');

      final deactivated = await db.getUserById('user-deactivate-test');
      expect(deactivated?.isActive, isFalse);
      expect(deactivated?.syncStatus, 2);
      expect(await db.getPendingSyncCount(), 1);
    });

    test('Version-aware acknowledgement: in-flight local modifications are preserved', () async {
      final now = DateTime.now();
      final initialPatient = Patient(
        id: 'patient-conflict-test',
        clinicId: 'clinic-1',
        firstName: 'Original',
        lastName: 'Name',
        updatedAt: now,
        syncStatus: 1,
      );

      await db.insertPatient(initialPatient);

      // Simulate: sync takes a snapshot of initialPatient
      final snapshot = initialPatient;

      // While push is in flight, user modifies patient locally
      final editedLocally = snapshot.copyWith(
        firstName: 'Modified While In Flight',
        updatedAt: now.add(const Duration(seconds: 1)),
        syncStatus: 2,
      );
      await db.updatePatient(editedLocally);

      // Sync finishes remote push of snapshot and attempts acknowledgement
      final currentLocal = await db.getPatientById(snapshot.id);
      if (currentLocal != null && currentLocal.updatedAt == snapshot.updatedAt) {
        // Stale acknowledgement - would have wiped local edit
        await db.updatePatient(currentLocal.copyWith(syncStatus: 0));
      }

      // Verify that local modification was NOT overwritten and still dirty (syncStatus == 2)
      final preserved = await db.getPatientById(snapshot.id);
      expect(preserved?.firstName, 'Modified While In Flight');
      expect(preserved?.syncStatus, 2);
      expect(await db.getPendingSyncCount(), 1);
    });
  });
}
