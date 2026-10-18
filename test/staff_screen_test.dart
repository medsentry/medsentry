import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/user.dart';
import 'package:medsentry/src/models/clinic.dart';
import 'package:medsentry/src/providers/providers.dart';
import 'package:medsentry/src/screens/staff_screen.dart';

void main() {
  testWidgets('StaffScreen renders user accounts properly', (tester) async {
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
      isActive: true,
      pinEnabled: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => mockUser),
          usersProvider.overrideWith((ref) => Future.value([mockUser, mockStaff])),
          clinicsProvider.overrideWith((ref) => Future.value(<Clinic>[])),
        ],
        child: MaterialApp(
          theme: buildMedSentryTheme(Brightness.dark),
          home: const Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: StaffScreen(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Elena Ramos'), findsOneWidget);
  });
}
