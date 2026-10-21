import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/clinic.dart';
import 'package:medsentry/src/models/user.dart';
import 'package:medsentry/src/providers/providers.dart';
import 'package:medsentry/src/repositories/auth_repository.dart';
import 'package:medsentry/src/screens/settings_screen.dart';
import 'package:medsentry/src/services/audit_service.dart';

// RHU Admins create RHU Admin and Staff accounts for their clinic; only a
// Super Admin creates Super Admins.
void main() {
  final admin = User(
    id: '00000000-0000-4000-8000-000000000021',
    email: 'admin@example.com',
    firstName: 'Ana',
    lastName: 'Cruz',
    role: UserRole.admin,
    clinicId: 'rhu-01',
    isActive: true,
    pinEnabled: false,
  );

  test('an RHU Admin cannot create a Super Admin account', () async {
    final dir = await Directory.systemTemp.createTemp('admin_role_limits');
    addTearDown(() => dir.delete(recursive: true));
    final db = SimpleDatabase();
    await db.useStoreFileForTesting(File('${dir.path}/store.json'));
    await db.insertUser(admin);
    final repo = AuthRepository(db, AuditService(db));

    await expectLater(
      repo.createUser(
        email: 'new.super@example.com',
        password: 'Strong#Pass123',
        firstName: 'New',
        lastName: 'Super',
        role: UserRole.superAdmin,
        createdByUserId: admin.id,
      ),
      throwsA(isA<StateError>()),
    );
  });

  testWidgets('an RHU Admin can assign the RHU Admin and Staff roles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => admin),
          clinicsProvider.overrideWith((ref) => Future.value(<Clinic>[])),
        ],
        child: const MaterialApp(home: Scaffold(body: StaffFormDialog())),
      ),
    );
    await tester.pumpAndSettle();

    // The field sits further down the scrolling form.
    final field = find.byType(DropdownButtonFormField<UserRole>);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();

    // With the menu open, the selected role shows in the field and the menu.
    expect(
      UserRole.values.where(
        (role) => find.text(role.name.toUpperCase()).evaluate().length >= 2,
      ),
      isNotEmpty,
      reason: 'the role menu did not open',
    );
    expect(find.text('ADMIN'), findsWidgets);
    expect(find.text('STAFF'), findsWidgets);
    expect(find.text('SUPERADMIN'), findsNothing);
  });
}
