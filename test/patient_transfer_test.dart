import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/models.dart';
import 'package:medsentry/src/services/audit_service.dart';
import 'package:medsentry/src/services/patient_transfer_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

void main() {
  late SimpleDatabase db;
  late Directory dir;
  late PatientTransferService service;

  const madrid = Clinic(id: 'madrid', name: 'RHU Madrid', code: 'RHU-MAD');
  const lanuza = Clinic(id: 'lanuza', name: 'RHU Lanuza', code: 'RHU-LAN');

  User user(UserRole role) => User(
    id: 'u-${role.name}',
    clinicId: role == UserRole.superAdmin ? null : 'madrid',
    email: '${role.name}@example.com',
    firstName: 'A',
    lastName: 'B',
    role: role,
    isActive: true,
    pinEnabled: false,
  );

  Patient patient({int sync = 0}) => Patient(
    id: 'p1',
    clinicId: 'madrid',
    firstName: 'Ana',
    lastName: 'Cruz',
    syncStatus: sync,
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('transfer');
    db = SimpleDatabase();
    await db.useStoreFileForTesting(File('${dir.path}/store.json'));
    // No signed-in session: any request that reached the server would fail.
    service = PatientTransferService(
      db,
      AuditService(db),
      client: SupabaseClient('http://localhost:1', 'test-key'),
    );
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<Object?> attempt(Patient p, Clinic target, User actor) async {
    try {
      await service.transfer(patient: p, target: target, actor: actor);
      return null;
    } catch (error) {
      return error;
    }
  }

  test('only a super admin can transfer', () async {
    final error = await attempt(patient(), lanuza, user(UserRole.admin));
    expect('$error', contains('Only a Super Administrator'));
  });

  test('a patient with unsynced changes is not transferred', () async {
    final error = await attempt(
      patient(sync: 2),
      lanuza,
      user(UserRole.superAdmin),
    );
    expect('$error', contains('not synced yet'));
  });

  test('transferring to the same RHU is refused', () async {
    final error = await attempt(patient(), madrid, user(UserRole.superAdmin));
    expect('$error', contains('already in RHU Madrid'));
  });

  test('transfer needs a connection', () async {
    final error = await attempt(patient(), lanuza, user(UserRole.superAdmin));
    expect('$error', contains('Connect to the internet'));
  });
}
