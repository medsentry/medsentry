import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/user.dart';
import 'package:medsentry/src/models/clinic.dart';
import 'package:medsentry/src/providers/providers.dart';
import 'package:medsentry/src/repositories/auth_repository.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/services/audit_service.dart';
import 'package:medsentry/src/screens/staff_screen.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(SimpleDatabase(), AuditService());

  String? deletedUserId;

  @override
  Future<void> deleteUser(String id, String deletedByUserId) async {
    deletedUserId = id;
  }
}

void main() {
  testWidgets('StaffScreen renders user accounts properly', (tester) async {
    final authRepository = _FakeAuthRepository();
    final mockUser = User(
      id: '00000000-0000-4000-8000-000000000001',
      email: 'superadmin@gmail.com',
      firstName: 'System',
      lastName: 'SuperAdmin',
      role: UserRole.superAdmin,
      isActive: true,
      pinEnabled: false,
    );

    final mockStaff = User(
      id: '00000000-0000-4000-8000-000000000002',
      email: 'staff@gmail.com',
      firstName: 'Elena',
      lastName: 'Ramos',
      role: UserRole.admin,
      clinicId: 'rhu-01',
      isActive: true,
      pinEnabled: false,
    );

    final inactiveStaff = User(
      id: '00000000-0000-4000-8000-000000000003',
      email: 'inactive@gmail.com',
      firstName: 'Inactive',
      lastName: 'Staff',
      role: UserRole.staff,
      clinicId: 'rhu-01',
      isActive: false,
      pinEnabled: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => mockUser),
          authRepositoryProvider.overrideWithValue(authRepository),
          usersProvider.overrideWith(
            (ref) => Future.value([mockUser, mockStaff, inactiveStaff]),
          ),
          clinicsProvider.overrideWith((ref) => Future.value(<Clinic>[])),
        ],
        child: MaterialApp(
          theme: buildMedSentryTheme(Brightness.dark),
          home: const Scaffold(
            body: SizedBox(width: 1200, height: 800, child: StaffScreen()),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Elena Ramos'), findsOneWidget);
    expect(find.text('All Facilities (2)'), findsOneWidget);
    // Super Admins have their own category instead of counting as
    // unassigned staff.
    expect(find.text('Super Admins (1)'), findsOneWidget);
    expect(find.text('Unassigned (0)'), findsOneWidget);
    expect(find.byTooltip('Delete user permanently'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete user permanently'));
    await tester.pumpAndSettle();
    expect(find.text('Delete User Permanently'), findsOneWidget);
    expect(find.textContaining('This cannot be undone.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete User Permanently'), findsNothing);

    await tester.tap(find.text('Inactive Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Inactive Staff'), findsOneWidget);
    expect(find.byTooltip('Delete user permanently'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete user permanently'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    expect(authRepository.deletedUserId, inactiveStaff.id);
    expect(find.text('Inactive Staff permanently deleted'), findsOneWidget);
  });

  testWidgets('an RHU Admin cannot manage another Admin', (tester) async {
    User account(String id, String first, UserRole role) => User(
      id: id,
      email: '$first@example.com',
      firstName: first,
      lastName: 'Cruz',
      role: role,
      clinicId: 'rhu-01',
      isActive: true,
      pinEnabled: false,
    );
    final me = account('00000000-0000-4000-8000-000000000011', 'Ana', UserRole.admin);
    final peerAdmin = account('00000000-0000-4000-8000-000000000012', 'Ben', UserRole.admin);
    final staff = account('00000000-0000-4000-8000-000000000013', 'Carla', UserRole.staff);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => me),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          usersProvider.overrideWith(
            (ref) => Future.value([me, peerAdmin, staff]),
          ),
          clinicsProvider.overrideWith((ref) => Future.value(<Clinic>[])),
        ],
        child: MaterialApp(
          theme: buildMedSentryTheme(Brightness.dark),
          home: const Scaffold(
            body: SizedBox(width: 1200, height: 800, child: StaffScreen()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Ben Cruz'), findsOneWidget);
    // Delete: only the staff member (never yourself, never a peer Admin).
    expect(find.byTooltip('Delete user permanently'), findsOneWidget);
    // Password reset: yourself and the staff member, not the peer Admin.
    expect(find.byTooltip('Reset Password (Reset PWD)'), findsNWidgets(2));
  });
}
