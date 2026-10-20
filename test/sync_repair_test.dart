import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/clinic.dart';
import 'package:medsentry/src/models/document.dart';
import 'package:medsentry/src/models/patient.dart';
import 'package:medsentry/src/models/user.dart';
import 'package:medsentry/src/repositories/clinic_repository.dart';
import 'package:medsentry/src/services/audit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

void main() {
  late SimpleDatabase db;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('medsentry_sync_repair');
    db = SimpleDatabase();
    await db.useStoreFileForTesting(File('${tempDir.path}/store.json'));
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Patient patient(String id, {String clinicId = 'clinic-a', int sync = 0}) =>
      Patient(
        id: id,
        clinicId: clinicId,
        firstName: 'Ana',
        lastName: 'Cruz',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        syncStatus: sync,
      );

  MedicalDocument document(String id, String patientId, String path) =>
      MedicalDocument(
        id: id,
        patientId: patientId,
        clinicId: 'clinic-a',
        type: DocumentType.labResult,
        title: 'Result',
        filePath: path,
        fileSize: 10,
        syncStatus: 0,
      );

  test('a batch of writes produces one change notification', () async {
    var notifications = 0;
    final sub = db.changes.listen((_) => notifications++);

    await db.runBatch(() async {
      for (var i = 0; i < 50; i++) {
        await db.insertPatient(patient('p$i'));
      }
    });
    await Future<void>.delayed(Duration.zero);

    expect(notifications, 1);
    expect(await db.getPatientCount(), 50);
    await sub.cancel();
  });

  test('a remote patient deletion removes its documents and reports their '
      'files', () async {
    await db.insertPatient(patient('p1'));
    await db.insertDocument(document('d1', 'p1', '/files/d1.enc'));
    await db.insertDocument(document('d2', 'p1', '/files/d2.enc'));
    await db.insertDocument(document('d3', 'other', '/files/d3.enc'));

    final paths = await db.applyRemoteDelete('patients', 'p1');

    expect(paths, unorderedEquals(['/files/d1.enc', '/files/d2.enc']));
    expect(await db.getPatientById('p1'), isNull);
    expect(await db.getDocumentById('d1'), isNull);
    expect(await db.getDocumentById('d3'), isNotNull);
    expect(await db.isPatientPurged('p1'), isTrue);
    expect(await db.getPendingSyncDeletes(), isEmpty);
  });

  test('replacing an offline clinic moves its records and queues them for '
      'upload', () async {
    await db.insertClinic(
      const Clinic(id: 'phantom', name: 'RHU Cantilan', code: 'RHU-CAN'),
    );
    await db.insertPatient(patient('p1', clinicId: 'phantom'));
    await db.insertUser(
      User(
        id: 'u1',
        clinicId: 'phantom',
        email: 'nurse@example.com',
        firstName: 'N',
        lastName: 'R',
        role: UserRole.staff,
        isActive: true,
        pinEnabled: false,
      ),
    );

    const real = Clinic(id: 'real', name: 'RHU Cantilan', code: 'RHU-CANTILAN');
    await db.replaceClinicId('phantom', real);

    final moved = await db.getPatientById('p1');
    expect(moved!.clinicId, 'real');
    expect(moved.syncStatus, isNot(0));
    expect((await db.getUserById('u1'))!.clinicId, 'real');
    expect((await db.getAllClinics()).map((c) => c.id), ['real']);
  });

  test('server clinics replace same-named clinics invented offline', () async {
    final repository = ClinicRepository(
      db,
      AuditService(db),
      SupabaseClient('http://localhost', 'test-key'),
    );
    await db.insertClinic(
      const Clinic(
        id: 'c1111111-1111-1111-1111-111111111111',
        name: 'RHU Cantilan',
        code: 'RHU-CAN',
      ),
    );
    await db.insertClinic(
      const Clinic(
        id: 'c2222222-2222-2222-2222-222222222222',
        name: 'RHU Madrid',
        code: 'RHU-MAD',
      ),
    );
    await db.insertPatient(
      patient('p1', clinicId: 'c1111111-1111-1111-1111-111111111111'),
    );

    await repository.reconcileWithRemote(const [
      Clinic(
        id: '33333333-3333-4333-8333-333333333333',
        name: 'RHU Cantilan',
        code: 'RHU-CANTILAN',
      ),
    ]);

    final clinicIds = (await db.getAllClinics()).map((c) => c.id).toSet();
    expect(clinicIds, {'33333333-3333-4333-8333-333333333333'});
    expect(
      (await db.getPatientById('p1'))!.clinicId,
      '33333333-3333-4333-8333-333333333333',
    );
  });

  test('sync cursors persist per key', () async {
    final at = DateTime.utc(2026, 10, 20, 8);
    await db.setSyncCursor('audit_logs:user-1', at);

    expect(await db.getSyncCursor('audit_logs:user-1'), at);
    expect(await db.getSyncCursor('audit_logs:user-2'), isNull);
  });
}
