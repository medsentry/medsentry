import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/audit_log.dart';
import 'package:medsentry/src/models/clinic.dart';
import 'package:medsentry/src/models/consultation.dart';
import 'package:medsentry/src/models/document.dart';
import 'package:medsentry/src/models/generated_report.dart';
import 'package:medsentry/src/models/system_notification.dart';

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

  test(
    'remote settings, reports, notifications, and audit logs refresh locally',
    () async {
      final initialRevision = db.revision;

      await db.applyRemoteUpsert('clinics', {
        'id': 'clinic-remote-1',
        'name': 'Remote RHU',
        'code': 'RHU-REM',
      });
      expect(
        (await db.getAllClinics()).single,
        isA<Clinic>().having((clinic) => clinic.name, 'name', 'Remote RHU'),
      );

      await db.applyRemoteUpsert('system_settings', {
        'key': 'clinic',
        'updated_at': '2026-10-08T10:00:00.000Z',
        'value': {'clinic_name': 'Updated RHU', 'auto_sync_enabled': false},
      });
      expect((await db.getSystemSettings()).clinicName, 'Updated RHU');
      expect((await db.getSystemSettings()).autoSyncEnabled, isFalse);

      await db.applyRemoteUpsert('generated_reports', {
        'id': 'report-remote-1',
        'title': 'Monthly summary',
        'type': 'monthly',
        'generated_at': '2026-10-08T10:00:00.000Z',
      });
      expect(
        (await db.getGeneratedReports()).single,
        isA<GeneratedReport>().having(
          (report) => report.title,
          'title',
          'Monthly summary',
        ),
      );

      await db.applyRemoteUpsert('notifications', {
        'id': 'notification-remote-1',
        'type': 'general',
        'target': 'super_admin',
        'priority': 'normal',
        'title': 'New update',
        'message': 'A record was updated.',
        'is_read': false,
        'created_at': '2026-10-08T10:00:00.000Z',
      });
      expect(
        (await db.getNotifications()).single,
        isA<SystemNotification>().having(
          (notification) => notification.target,
          'target',
          NotificationTarget.admin,
        ),
      );

      await db.applyRemoteUpsert('audit_logs', {
        'id': 'audit-remote-1',
        'user_id': 'user-remote-1',
        'action': 'patient_updated',
        'entity_type': 'patients',
        'entity_id': 'patient-remote-1',
        'occurred_at': '2026-10-08T10:00:00.000Z',
      });
      expect(
        (await db.getAllAuditLogs()).single,
        isA<AuditLog>()
            .having((log) => log.action, 'action', AuditAction.update)
            .having((log) => log.isSynced, 'isSynced', isTrue),
      );
      expect(db.revision, greaterThan(initialRevision));
    },
  );

  test(
    'a remote update does not replace an unsynced local patient edit',
    () async {
      const patientId = 'pat-local-pending';
      final patientRaw = {
        'id': patientId,
        'first_name': 'Local',
        'last_name': 'Patient',
        'gender': 'Male',
        'created_at': '2026-10-08T10:00:00.000Z',
        'updated_at': '2026-10-08T10:00:00.000Z',
      };
      await db.applyRemoteUpsert('patients', patientRaw);
      final localPatient = (await db.getPatientById(patientId))!;
      await db.updatePatient(
        localPatient.copyWith(
          firstName: 'Unsynced',
          syncStatus: 1,
          updatedAt: DateTime.parse('2026-10-08T10:01:00.000Z'),
        ),
      );

      await db.applyRemoteUpsert('patients', {
        ...patientRaw,
        'first_name': 'Remote',
        'updated_at': '2026-10-08T10:02:00.000Z',
      });

      expect((await db.getPatientById(patientId))?.firstName, 'Unsynced');
    },
  );

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
