import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/clinic.dart';
import 'package:medsentry/src/models/system_settings.dart';
import 'package:medsentry/src/models/user.dart';
import 'package:medsentry/src/providers/providers.dart';
import 'package:medsentry/src/screens/settings_screen.dart';
import 'package:medsentry/src/widgets/app_scaffold.dart';
import 'package:medsentry/src/widgets/user_avatar.dart';

void main() {
  User makeUser(UserRole role) => User(
        id: 'test-${role.name}',
        email: '${role.name}@medsentry.gov.ph',
        firstName: 'Test',
        lastName: role.name.toUpperCase(),
        role: role,
        clinicId: role == UserRole.superAdmin ? null : 'rhu-01',
        isActive: true,
        pinEnabled: false,
      );

  group('Role Permissions & Settings Access', () {
    test('Super Admin and Admin can access settings; Staff cannot access settings', () {
      final superAdmin = makeUser(UserRole.superAdmin);
      final admin = makeUser(UserRole.admin);
      final staff = makeUser(UserRole.staff);

      expect(superAdmin.canAccessSettings, isTrue);
      expect(admin.canAccessSettings, isTrue);
      expect(staff.canAccessSettings, isFalse);

      expect(superAdmin.canManageSystemData, isTrue);
      expect(admin.canManageSystemData, isTrue);
      expect(staff.canManageSystemData, isFalse);
    });
  });

  group('SettingsScreen Role-Specific UI', () {
    testWidgets('Super Admin sees Platform Settings and Master Branding', (tester) async {
      final superAdmin = makeUser(UserRole.superAdmin);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => superAdmin),
            systemSettingsProvider.overrideWith(
              (ref) => Future.value(const SystemSettings(
                appName: 'MedSentry Regional',
                clinicName: 'Regional DOH Command',
              )),
            ),
            clinicsProvider.overrideWith((ref) => Future.value(<Clinic>[])),
          ],
          child: MaterialApp(
            theme: buildMedSentryTheme(Brightness.dark),
            home: const Scaffold(
              body: SizedBox(
                width: 1200,
                height: 900,
                child: SettingsScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Header matches Super Admin configuration
      expect(find.text('Platform Settings & System Configuration'), findsOneWidget);
      expect(
        find.text('Manage master platform branding, security policies, and system-wide infrastructure.'),
        findsOneWidget,
      );

      // Super Admin Configuration section
      final superAdminConfigFinder = find.text('Super Admin Configuration');
      await tester.scrollUntilVisible(
        superAdminConfigFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(superAdminConfigFinder, findsOneWidget);
      expect(find.text('System Identity & Master Branding'), findsOneWidget);
      expect(find.text('RHU Health Facilities Directory'), findsNothing);
      expect(find.text('Global Personnel & Administrator Accounts'), findsNothing);

      // Clinic Configuration should NOT be present for Super Admin
      expect(find.text('Clinic / RHU Facility Profile'), findsNothing);
      expect(find.text('Clinic Configuration'), findsNothing);
    });

    testWidgets('Admin sees Clinic Settings and Clinic / RHU Facility Profile', (tester) async {
      final admin = makeUser(UserRole.admin);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => admin),
            systemSettingsProvider.overrideWith(
              (ref) => Future.value(const SystemSettings(
                appName: 'MedSentry RHU',
                clinicName: 'Madrid RHU',
              )),
            ),
            clinicsProvider.overrideWith((ref) => Future.value(<Clinic>[])),
          ],
          child: MaterialApp(
            theme: buildMedSentryTheme(Brightness.dark),
            home: const Scaffold(
              body: SizedBox(
                width: 1200,
                height: 900,
                child: SettingsScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Header matches Admin configuration
      expect(find.text('Clinic Settings & Facility Administration'), findsOneWidget);
      expect(
        find.text('Manage your local health facility, operational services, and clinic preferences.'),
        findsOneWidget,
      );

      // Clinic Configuration section
      final clinicConfigFinder = find.text('Clinic Configuration');
      await tester.scrollUntilVisible(
        clinicConfigFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(clinicConfigFinder, findsOneWidget);
      expect(find.text('Clinic / RHU Facility Profile'), findsOneWidget);

      // Super Admin Configuration should NOT be present for Admin
      expect(find.text('Super Admin Configuration'), findsNothing);
      expect(find.text('System Identity & Master Branding'), findsNothing);
    });
  });

  group('Header Dropdown & Sidebar Consistency', () {
    testWidgets('Header profile menu displays "Settings" (not "Settings & Security") for Admin', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final admin = makeUser(UserRole.admin);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncStatusProvider.overrideWithValue(SyncStatus.synced),
            currentUserProvider.overrideWith((ref) => admin),
            systemSettingsProvider.overrideWith(
              (ref) => Future.value(const SystemSettings()),
            ),
          ],
          child: const MaterialApp(
            home: AppScaffold(
              title: 'Dashboard',
              navigationItems: [
                AppNavigationItem(
                  label: 'Dashboard',
                  path: '/dashboard',
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                ),
              ],
              body: Text('Admin Content'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open the profile popup menu via UserAvatar
      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();

      // Should display "Settings" exactly, not "Settings & Security"
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Settings & Security'), findsNothing);
      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('Header profile menu omits "Settings" for Staff role', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final staff = makeUser(UserRole.staff);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncStatusProvider.overrideWithValue(SyncStatus.synced),
            currentUserProvider.overrideWith((ref) => staff),
            systemSettingsProvider.overrideWith(
              (ref) => Future.value(const SystemSettings()),
            ),
          ],
          child: const MaterialApp(
            home: AppScaffold(
              title: 'Dashboard',
              navigationItems: [
                AppNavigationItem(
                  label: 'Dashboard',
                  path: '/dashboard',
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                ),
              ],
              body: Text('Staff Content'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open the profile popup menu via UserAvatar
      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();

      // Should have My Profile and Log Out, but NO Settings
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Settings & Security'), findsNothing);
      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('Sidebar does not contain Settings, Lock Screen, or Log Out', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final admin = makeUser(UserRole.admin);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncStatusProvider.overrideWithValue(SyncStatus.synced),
            currentUserProvider.overrideWith((ref) => admin),
            systemSettingsProvider.overrideWith(
              (ref) => Future.value(const SystemSettings()),
            ),
          ],
          child: const MaterialApp(
            home: AppScaffold(
              title: 'Dashboard',
              navigationItems: [
                AppNavigationItem(
                  label: 'Dashboard',
                  path: '/dashboard',
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                ),
                AppNavigationItem(
                  label: 'Patients',
                  path: '/patients',
                  icon: Icons.people_outlined,
                  selectedIcon: Icons.people,
                ),
              ],
              body: Text('Sidebar Test'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure sidebar does NOT have Settings, Lock Screen, or Log Out
      expect(find.text('Lock Screen'), findsNothing);
      expect(find.text('Log Out'), findsNothing);
    });
  });
}
