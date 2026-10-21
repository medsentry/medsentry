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

  test('an RHU Admin cannot create an Admin account', () async {
    final dir = await Directory.systemTemp.createTemp('admin_role_limits');
    addTearDown(() => dir.delete(recursive: true));
    final db = SimpleDatabase();
    await db.useStoreFileForTesting(File('${dir.path}/store.json'));
    await db.insertUser(admin);
    final repo = AuthRepository(db, AuditService(db));

    await expectLater(
      repo.createUser(
        email: 'new.admin@example.com',
        password: 'Strong#Pass123',
        firstName: 'New',
        lastName: 'Admin',
        role: UserRole.admin,
        clinicId: 'rhu-01',
        createdByUserId: admin.id,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Only a super administrator'),
        ),
      ),
    );
  });

  Future<List<String>> roleChoices(WidgetTester tester, {User? editing}) async {
    tester.view.physicalSize = const Size(1400, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => admin),
          clinicsProvider.overrideWith((ref) => Future.value(<Clinic>[])),
        ],
        child: MaterialApp(
          home: Scaffold(body: StaffFormDialog(existingUser: editing)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Opening the menu shows every role it offers. The field sits further
    // down the scrolling form, so bring it into view first.
    final field = find.byType(DropdownButtonFormField<UserRole>);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    // With the menu open, the selected role shows in the field and the menu.
    final shownTwice = UserRole.values.where(
      (role) => find.text(role.name.toUpperCase()).evaluate().length >= 2,
    );
    expect(shownTwice, isNotEmpty, reason: 'the role menu did not open');
    return [
      for (final role in UserRole.values)
        if (find.text(role.name.toUpperCase()).evaluate().isNotEmpty)
          role.name.toUpperCase(),
    ];
  }

  testWidgets('an RHU Admin can only assign the Staff role', (tester) async {
    expect(await roleChoices(tester), ['STAFF']);
  });

  testWidgets('an RHU Admin editing themselves keeps the Admin role', (
    tester,
  ) async {
    expect(await roleChoices(tester, editing: admin), ['ADMIN']);
  });
}
