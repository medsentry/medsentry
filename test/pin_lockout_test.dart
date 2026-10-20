import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/models.dart';
import 'package:medsentry/src/repositories/auth_repository.dart';
import 'package:medsentry/src/services/audit_service.dart';
import 'package:medsentry/src/utils/password_crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

void main() {
  late SimpleDatabase db;
  late Directory dir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-key',
      // No deep-link listener: its plugin does not exist in tests, and its
      // late error failed whichever test happened to be running.
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pin_lockout');
    db = SimpleDatabase();
    await db.useStoreFileForTesting(File('${dir.path}/store.json'));
    await db.insertUser(
      User(
        id: 'admin-1',
        email: 'admin@example.com',
        firstName: 'Ana',
        lastName: 'Admin',
        role: UserRole.superAdmin,
        isActive: true,
        pinEnabled: true,
        pinHash: PasswordCrypto.hash('1234'),
      ),
    );
    await db.setLastUserId('admin-1');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  // A new repository models the app being closed and reopened.
  AuthRepository reopenApp() => AuthRepository(db, AuditService(db));

  Future<Object?> attempt(String pin) async {
    try {
      return await reopenApp().loginWithPin(pin);
    } catch (error) {
      return error;
    }
  }

  test('the lockout survives reopening the app', () async {
    for (var i = 0; i < 4; i++) {
      expect(await attempt('0000'), isNull);
    }
    expect('${await attempt('0000')}', contains('locked for 5 minutes'));

    // Even the correct PIN is refused while locked, after a reopen.
    expect('${await attempt('1234')}', contains('PIN login locked'));
  });

  test('ten wrong PINs require a password sign-in', () async {
    for (var i = 0; i < 5; i++) {
      await attempt('0000');
    }
    // Let the first timed lock expire.
    final guard = await db.getPinGuard('admin-1');
    await db.setPinGuard(
      'admin-1',
      recent: guard.recent,
      total: guard.total,
      lockedUntil: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    for (var i = 0; i < 4; i++) {
      expect(await attempt('0000'), isNull);
    }
    expect('${await attempt('0000')}', contains('Sign in with your email'));

    expect('${await attempt('1234')}', contains('Sign in with your email'));
    expect(await reopenApp().isPinLoginAvailable(), isFalse);
  });

  test('a correct PIN clears earlier failures', () async {
    for (var i = 0; i < 3; i++) {
      await attempt('0000');
    }
    final user = await attempt('1234');
    expect(user, isA<User>());
    final guard = await db.getPinGuard('admin-1');
    expect(guard.total, 0);
    expect(guard.recent, 0);
  });
}
