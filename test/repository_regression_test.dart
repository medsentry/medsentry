import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/audit_log.dart';
import 'package:medsentry/src/models/queue.dart';
import 'package:medsentry/src/repositories/patient_repository.dart';
import 'package:medsentry/src/services/audit_service.dart';
import 'package:medsentry/src/services/triage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SimpleDatabase db;
  late File storeFile;
  late AuditService auditService;
  late PatientRepository repository;

  setUp(() async {
    db = SimpleDatabase();
    final tempDir = await Directory.systemTemp.createTemp('medsentry_test_');
    storeFile = File('${tempDir.path}/store.json');
    await db.useStoreFileForTesting(storeFile);
    await db.clearAll();
    auditService = AuditService(db);
    repository = PatientRepository(db, auditService);
  });

  test(
    'patient updates can clear nullable fields and audit old/new values',
    () async {
      final patient = await repository.createPatient(
        firstName: 'Ana',
        lastName: 'Reyes',
        contactNumber: '09123456789',
        email: 'ana@example.test',
        allergies: 'Penicillin',
        userId: 'user-1',
      );

      final updated = await repository.updatePatient(
        id: patient.id,
        clearFields: {'email', 'allergies'},
        userId: 'user-1',
      );

      expect(updated.email, isNull);
      expect(updated.allergies, isNull);

      final logs = await auditService.getLogsForPatient(patient.id);
      final updateLog = logs.firstWhere(
        (log) => log.action == AuditAction.update,
      );
      expect(jsonDecode(updateLog.oldValues!)['email'], 'ana@example.test');
      expect(jsonDecode(updateLog.newValues!)['email'], isNull);
    },
  );

  test('critical red flags always produce emergency priority', () {
    final priority = TriageService.calculatePriority(
      redFlags: [RedFlag.difficultyBreathing],
      isEssentiallyNormal: true,
    );

    expect(priority, Priority.emergency);
  });

  test('deleted queue records remain in the durable sync outbox', () async {
    final item = QueueItem(
      id: 'queue-record',
      patientId: 'patient-record',
      arrivalTime: DateTime.utc(2026, 9, 29),
    );
    await db.updateQueueItem(item);
    await db.deleteQueueItem(item.id);

    await db.useStoreFileForTesting(storeFile);
    expect(await db.getPendingSyncDeletes(), [
      containsPair('table', 'queue_items'),
    ]);
    expect(await db.getPendingSyncCount(), 1);
  });
}
