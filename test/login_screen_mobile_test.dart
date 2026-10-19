import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/system_settings.dart';
import 'package:medsentry/src/providers/providers.dart';
import 'package:medsentry/src/repositories/auth_repository.dart';
import 'package:medsentry/src/repositories/otp_gateway.dart';
import 'package:medsentry/src/screens/login_screen.dart';
import 'package:medsentry/src/services/audit_service.dart';
import 'package:medsentry/src/widgets/system_logo.dart';

class _FakeOtpGateway implements OtpGateway {
  @override
  bool get hasSession => false;

  @override
  Future<String> verifyPassword(String email, String password) async =>
      'auth-$email';

  @override
  Future<void> sendOtp(String email) async {}

  @override
  Future<String> verifyOtp(String email, String code) async => 'auth-$email';

  @override
  Future<void> signOutLocal() async {}

  @override
  Future<Map<String, dynamic>?> fetchProfile(String authUserId) async => null;

  @override
  Future<void> logLoginEvent() async {}
}

void main() {
  late Directory tempDir;
  late SimpleDatabase db;
  late AuthRepository authRepo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('medsentry_login_test');
    db = SimpleDatabase();
    await db.useStoreFileForTesting(File('${tempDir.path}/store.json'));
    authRepo = AuthRepository(
      db,
      AuditService(db),
      otpGateway: _FakeOtpGateway(),
    );
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  Widget createSubject({bool loadSettingsFromDatabase = false}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(authRepo),
        if (!loadSettingsFromDatabase)
          systemSettingsProvider.overrideWith(
            (ref) => Future.value(
              const SystemSettings(
                appName: 'MedSentry RHU',
                organizationName: 'Rural Health Unit',
              ),
            ),
          ),
      ],
      child: const MaterialApp(home: LoginScreen()),
    );
  }

  testWidgets(
    'renders cleanly on standard mobile portrait (390x844) without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('MedSentry RHU'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Remember Me'), findsOneWidget);
      expect(find.text('Sign in securely'), findsOneWidget);
      expect(find.textContaining('All Rights Reserved'), findsOneWidget);

      final loginCard = tester.getRect(
        find.byKey(const ValueKey('login-form-card')),
      );
      expect(loginCard.center.dx, closeTo(195, 1));
      expect(loginCard.center.dy, closeTo(422, 1));
    },
  );

  testWidgets('centers sign-in fields in the whole desktop window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    final loginCard = tester.getRect(
      find.byKey(const ValueKey('login-form-card')),
    );
    expect(loginCard.center.dx, closeTo(720, 1));
    expect(loginCard.center.dy, closeTo(450, 1));
  });

  testWidgets('shows the updated system logo on the login screen immediately', (
    tester,
  ) async {
    const initialLogo = 'data:image/png;base64,aGVsbG8=';
    const updatedLogo = 'data:image/png;base64,dXBkYXRlZA==';
    await tester.runAsync(
      () => db.updateSystemSettings(
        const SystemSettings(
          appName: 'MedSentry RHU',
          organizationName: 'Rural Health Unit',
          logoDataUri: initialLogo,
        ),
      ),
    );

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createSubject(loadSettingsFromDatabase: true));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SystemLogo>(find.byType(SystemLogo)).dataUri,
      initialLogo,
    );

    await tester.runAsync(() async {
      await db.updateSystemSettings(
        (await db.getSystemSettings()).copyWith(logoDataUri: updatedLogo),
      );
    });
    await tester.pumpAndSettle();

    expect(
      tester.widget<SystemLogo>(find.byType(SystemLogo)).dataUri,
      updatedLogo,
    );
  });

  testWidgets(
    'renders cleanly on narrow mobile portrait (320x568) without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in securely'), findsOneWidget);
    },
  );

  testWidgets('renders cleanly when mobile soft keyboard opens (390x420)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Scrollable content should be present and scroll without issue
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Remember Me label toggles checkbox on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);
    Checkbox checkbox = tester.widget(checkboxFinder);
    // SimpleDatabase defaults remember_me to true
    expect(checkbox.value, isTrue);

    // Tap on the label text to uncheck
    await tester.tap(find.text('Remember Me'));
    await tester.pumpAndSettle();

    checkbox = tester.widget(checkboxFinder);
    expect(checkbox.value, isFalse);

    // Tap again to re-check
    await tester.tap(find.text('Remember Me'));
    await tester.pumpAndSettle();

    checkbox = tester.widget(checkboxFinder);
    expect(checkbox.value, isTrue);
  });
}
