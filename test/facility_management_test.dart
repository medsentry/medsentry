import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/models.dart';
import 'package:medsentry/src/providers/providers.dart';
import 'package:medsentry/src/repositories/clinic_repository.dart';
import 'package:medsentry/src/screens/facility_detail_screen.dart';
import 'package:medsentry/src/screens/patients_screen.dart';
import 'package:medsentry/src/screens/staff_screen.dart';
import 'package:medsentry/src/services/audit_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

User _account(String id, UserRole role, String? clinicId, String name) => User(
  id: id,
  clinicId: clinicId,
  email: '$id@example.com',
  firstName: name,
  lastName: 'Tester',
  role: role,
  isActive: true,
  pinEnabled: false,
);

Patient _patient(String id, String clinicId, String lastName) => Patient(
  id: id,
  clinicId: clinicId,
  firstName: 'Ana',
  lastName: lastName,
  barangay: 'Poblacion',
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  syncStatus: 0,
);

void main() {
  late SimpleDatabase db;
  late Directory dir;
  final superAdmin = _account('boss', UserRole.superAdmin, null, 'Boss');

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-key',
    );
  });

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('facility_mgmt');
      db = SimpleDatabase();
      await db.useStoreFileForTesting(File('${dir.path}/store.json'));
      await db.insertClinic(
        const Clinic(id: 'madrid', name: 'RHU Madrid', code: 'RHU-MAD'),
      );
      await db.insertClinic(
        const Clinic(id: 'lanuza', name: 'RHU Lanuza', code: 'RHU-LAN'),
      );
      await db.insertUser(superAdmin);
      await db.insertUser(_account('m1', UserRole.staff, 'madrid', 'Mara'));
      await db.insertUser(_account('l1', UserRole.admin, 'lanuza', 'Lito'));
      await db.insertPatient(_patient('p-m', 'madrid', 'Madridano'));
      await db.insertPatient(_patient('p-l', 'lanuza', 'Lanuzano'));
    });
  }

  Widget app(Widget child) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clinicRepositoryProvider.overrideWithValue(
        ClinicRepository(db, AuditService(db)),
      ),
      currentUserProvider.overrideWith((ref) => superAdmin),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  setUp(() {});

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  testWidgets('a facility page lists only that facility\'s staff and '
      'patients', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await seed(tester);

    await tester.pumpWidget(
      app(const FacilityDetailScreen(clinicId: 'madrid')),
    );
    await settle(tester);

    expect(find.text('RHU Madrid'), findsWidgets);
    expect(find.text('Staff (1)'), findsOneWidget);
    expect(find.text('Patients (1)'), findsOneWidget);
    expect(find.textContaining('Mara'), findsWidgets);
    expect(find.textContaining('Lito'), findsNothing);

    await tester.tap(find.text('Patients (1)'));
    await settle(tester);
    expect(find.textContaining('Madridano'), findsWidgets);
    expect(find.textContaining('Lanuzano'), findsNothing);
  });

  testWidgets('a super admin sees patients grouped by facility', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await seed(tester);

    await tester.pumpWidget(app(const PatientsScreen()));
    await settle(tester);

    expect(find.text('RHU Madrid'), findsOneWidget);
    expect(find.text('RHU Lanuza'), findsOneWidget);
  });

  testWidgets('super admins are their own staff category', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await seed(tester);

    await tester.pumpWidget(app(const StaffScreen()));
    await settle(tester);

    expect(find.text('Super Admins (1)'), findsOneWidget);
    expect(find.text('Unassigned (0)'), findsOneWidget);
  });
}
