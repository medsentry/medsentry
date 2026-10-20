import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/login_challenge.dart';
import 'package:medsentry/src/models/models.dart';
import 'package:medsentry/src/repositories/auth_repository.dart';
import 'package:medsentry/src/services/audit_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

void main() {
  late SimpleDatabase db;
  late Directory dir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The test binding answers every HTTP request with a fake 400; use real
    // sockets so the request fails the way it does without a connection.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    // Nothing listens on port 9, so every request fails like a dead network.
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      publishableKey: 'test-key',
    );
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('login_network');
    db = SimpleDatabase();
    await db.useStoreFileForTesting(File('${dir.path}/store.json'));
    // A super admin cached on this device without a usable local password,
    // so sign-in has to reach the server.
    await db.insertUser(
      User(
        id: 'boss',
        email: 'boss@example.com',
        firstName: 'Boss',
        lastName: 'Admin',
        role: UserRole.superAdmin,
        isActive: true,
        pinEnabled: false,
      ),
    );
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('an unreachable server is reported as a connection problem', () async {
    final repo = AuthRepository(db, AuditService(db));

    final result = await repo.beginLogin('boss@example.com', 'Correct#Pass1');

    expect(result, isA<LoginFailure>());
    final failure = result as LoginFailure;
    expect(failure.isNetworkError, isTrue);
    expect(failure.message, isNot(contains('Invalid email or password')));
  });
}
