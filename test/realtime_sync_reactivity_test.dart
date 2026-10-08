import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/audit_log.dart';
import 'package:medsentry/src/models/consultation.dart';
import 'package:medsentry/src/models/document.dart';

void main() {
  late SimpleDatabase db;
  late Directory tempDir;
  late File storeFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('medsentry_rt_test');
    storeFile = File('${tempDir.path}/test_store.json');
    db = SimpleDatabase();
    await db.useStoreFileForTesting(storeFile);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('SimpleDatabase emits revision increments on notifyChanges', () async {
    final revisions = <int>[];
    final sub = db.changes.listen(revisions.add);

    final initialRev = db.revision;
    db.notifyChanges();
    db.notifyChanges();

    await Future.delayed(const Duration(milliseconds: 50));
    expect(revisions, [initialRev + 1, initialRev + 2]);
    await sub.cancel();
  });

  test('applyRemoteUpsert stores patients reactively', () async {
    final patientId = 'pat-test-101';
    final patientRaw = {
      'id': patientId,
      'first_name': 'Juan',
      'last_name': 'Dela Cruz',
      'gender': 'Male',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await db.applyRemoteUpsert('patients', patientRaw);
    expect((await db.getPatientById(patientId))?.fullName, 'Juan Dela Cruz');
  });

  test('purge removes queue data from a legacy local store', () async {
    await storeFile.writeAsString(
      jsonEncode({
        'version': 1,
        'queue_items': [
          {'id': 'old-queue-item'},
        ],
        'documents': [
          {
            'id': 'retained-document',
            'patient_id': 'patient-1',
            'consultation_id': 'old-consultation',
            'type': 'other',
            'title': 'Patient document',
            'file_path': 'document.pdf',
            'file_size': 10,
            'status': 'pending',
          },
        ],
      }),
    );
    await db.useStoreFileForTesting(storeFile);

    await db.purgeRetiredClinicalData();

    final saved =
        jsonDecode(await storeFile.readAsString()) as Map<String, dynamic>;
    expect(saved.containsKey('queue_items'), isFalse);
    final savedDocuments = saved['documents'] as List<dynamic>;
    expect(savedDocuments, hasLength(1));
    expect(
      (savedDocuments.single as Map<String, dynamic>).containsKey(
        'consultation_id',
      ),
      isFalse,
    );
  });

  test(
    'purgeRetiredClinicalData removes retired records and preserves documents',
    () async {
      final now = DateTime.now();
      await db.insertConsultation(
        Consultation(id: 'c-purge', patientId: 'p-purge'),
      );
      await db.insertPrescription(
        Prescription(
          id: 'rx-purge',
          consultationId: 'c-purge',
          medicationName: 'Medication',
          dosage: '1 tablet',
          frequency: 'Daily',
          duration: '5 days',
          quantity: 5,
        ),
      );
      await db.insertLabOrder(
        LabOrder(
          id: 'lab-purge',
          consultationId: 'c-purge',
          testName: 'Blood test',
        ),
      );
      await db.insertDocument(
        MedicalDocument(
          id: 'doc-purge',
          patientId: 'p-purge',
          type: DocumentType.other,
          title: 'Patient document',
          filePath: 'document.pdf',
          fileSize: 1,
        ),
      );
      await db.insertAuditLog(
        AuditLog(
          id: 'audit-consultation',
          userId: 'u-test',
          action: AuditAction.create,
          entityType: 'consultations',
          timestamp: now,
        ),
      );
      await db.insertAuditLog(
        AuditLog(
          id: 'audit-patient',
          userId: 'u-test',
          action: AuditAction.update,
          entityType: 'patients',
          timestamp: now,
        ),
      );

      await db.purgeRetiredClinicalData();

      expect(await db.getAllConsultations(), isEmpty);
      expect(await db.getAllPrescriptions(), isEmpty);
      expect(await db.getLabOrdersForConsultation('c-purge'), isEmpty);
      final retainedDocument = await db.getDocumentById('doc-purge');
      expect(retainedDocument, isNotNull);
      expect(
        retainedDocument!.toJson().containsKey('consultation_id'),
        isFalse,
      );
      final auditLogs = await db.getAllAuditLogs();
      expect(auditLogs.map((log) => log.id), ['audit-patient']);

      final deletes = await db.getPendingSyncDeletes();
      expect(deletes, isEmpty);
    },
  );
}
