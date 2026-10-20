import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/models.dart';
import 'package:medsentry/src/providers/providers.dart';
import 'package:medsentry/src/screens/patients_screen.dart';
import 'package:medsentry/src/widgets/app_form_dialog.dart';

void main() {
  Widget buildTestWidget({VoidCallback? onPatientAdded}) {
    return ProviderScope(
      child: MaterialApp(
        theme: buildMedSentryTheme(Brightness.light),
        darkTheme: buildMedSentryTheme(Brightness.dark),
        home: Scaffold(
          body: PatientRegistrationDialog(
            onPatientAdded: onPatientAdded ?? () {},
          ),
        ),
      ),
    );
  }

  group('Patient Registration Form - No Stepper Tests', () {
    testWidgets('renders inside AppFormDialog with correct title and subtitle', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(AppFormDialog), findsOneWidget);
      expect(find.text('New Patient Registration'), findsOneWidget);
      expect(
        find.textContaining('demographic, residence, emergency contact, and medical details'),
        findsOneWidget,
      );
    });

    testWidgets('guarantees zero Stepper or Step widgets in the entire form hierarchy', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Explicit verification that legacy Stepper UX is completely removed
      expect(find.byType(Stepper), findsNothing);
      expect(find.text('Step 1'), findsNothing);
      expect(find.text('Step 2'), findsNothing);
      expect(find.text('Step 3'), findsNothing);
      expect(find.text('Step 4'), findsNothing);
    });

    testWidgets('contains all 4 cohesive sections in a single unified scrollable layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(AppFormSection), findsNWidgets(4));
      final sections = tester.widgetList<AppFormSection>(find.byType(AppFormSection)).toList();
      expect(sections[0].title, 'Personal Demographics');
      expect(sections[1].title, 'Address & Contact Details');
      expect(sections[2].title, 'Emergency Contact Person');
      expect(sections[3].title, 'Medical Profile & PhilHealth');
    });

    testWidgets('renders all required form fields and action buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check personal demographics section fields
      expect(find.textContaining('First Name (FN)'), findsOneWidget);
      expect(find.textContaining('Last Name (LN)'), findsOneWidget);
      expect(find.textContaining('Date of Birth'), findsOneWidget);

      // Check emergency contact section fields
      expect(find.textContaining('Relationship'), findsOneWidget);
      expect(find.textContaining('Emergency Contact Number'), findsOneWidget);

      // Check medical section fields
      expect(find.textContaining('PhilHealth Number'), findsOneWidget);
      expect(find.textContaining('Blood Type'), findsOneWidget);

      // Check actions
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Register Patient'), findsOneWidget);
    });
  });

  group('Patient Registration Form - RHU assignment', () {
    User user(UserRole role, String? clinicId) => User(
      id: 'u-${role.name}',
      clinicId: clinicId,
      email: '${role.name}@example.com',
      firstName: 'Test',
      lastName: 'User',
      role: role,
      isActive: true,
      pinEnabled: false,
    );

    Widget buildFor(User current) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => current),
        clinicsProvider.overrideWith(
          (ref) async => const [
            Clinic(id: 'clinic-parang', name: 'RHU Parang', code: 'RHU-PARANG'),
          ],
        ),
      ],
      child: MaterialApp(
        theme: buildMedSentryTheme(Brightness.light),
        home: Scaffold(body: PatientRegistrationDialog(onPatientAdded: () {})),
      ),
    );

    testWidgets('a super admin must choose the patient RHU', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildFor(user(UserRole.superAdmin, null)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rural Health Unit'), findsOneWidget);
    });

    testWidgets('clinic staff register into their own RHU without a picker', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildFor(user(UserRole.staff, 'clinic-parang')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rural Health Unit'), findsNothing);
    });
  });
}
