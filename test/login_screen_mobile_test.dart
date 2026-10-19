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

final _testSystemSettingsProvider = StateProvider<SystemSettings>(
  (ref) => const SystemSettings(),
);

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

  Widget createSubject({SystemSettings? systemSettings}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(authRepo),
        _testSystemSettingsProvider.overrideWith(
          (ref) =>
              systemSettings ??
              const SystemSettings(
                appName: 'MedSentry RHU',
                organizationName: 'Rural Health Unit',
              ),
        ),
        systemSettingsProvider.overrideWith(
          (ref) => Future.value(ref.watch(_testSystemSettingsProvider)),
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

  testWidgets('shows the clinic photo as a full-screen login background', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    final background = tester.widget<Image>(
      find.byKey(const ValueKey('login-background-image')),
    );

    expect(
      (background.image as AssetImage).assetName,
      'assets/images/rhu_background.jpg',
    );
    expect(background.fit, BoxFit.cover);
  });

  testWidgets('shows the updated system logo on the login screen immediately', (
    tester,
  ) async {
    const initialSettings = SystemSettings(
      appName: 'MedSentry RHU',
      organizationName: 'Rural Health Unit',
      logoDataUri: 'data:image/png;base64,aGVsbG8=',
    );
    const updatedLogo = 'data:image/png;base64,dXBkYXRlZA==';

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createSubject(systemSettings: initialSettings));
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<SystemLogo>(find.byType(SystemLogo)).dataUri,
      initialSettings.logoDataUri,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LoginScreen)),
    );
    container.read(_testSystemSettingsProvider.notifier).state = initialSettings
        .copyWith(logoDataUri: updatedLogo);
    await tester.pump();
    await tester.pump();

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
