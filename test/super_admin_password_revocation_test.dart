import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/login_challenge.dart';
import 'package:medsentry/src/models/models.dart';
import 'package:medsentry/src/repositories/auth_repository.dart';
import 'package:medsentry/src/services/audit_service.dart';
import 'package:medsentry/src/utils/password_crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

/// How the fake auth server answers a password sign-in.
enum _ServerMode { rejectPassword, outage, dropConnection }

void main() {
  late HttpServer server;
  var mode = _ServerMode.rejectPassword;
  late SimpleDatabase db;
  late Directory dir;

  const email = 'boss@example.com';
  const oldPassword = 'Old#Pass123';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The test binding answers every HTTP request with a fake 400; use real
    // sockets so requests reach the fake server below.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      switch (mode) {
        case _ServerMode.rejectPassword:
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'code': 400,
                'error_code': 'invalid_credentials',
                'msg': 'Invalid login credentials',
              }),
            );
          await request.response.close();
        case _ServerMode.outage:
          request.response
            ..statusCode = 503
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'code': 503, 'msg': 'upstream unavailable'}));
          await request.response.close();
        case _ServerMode.dropConnection:
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          socket.destroy();
      }
    });

    await Supabase.initialize(
      url: 'http://127.0.0.1:${server.port}',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('password_revocation');
    db = SimpleDatabase();
    await db.useStoreFileForTesting(File('${dir.path}/store.json'));
    // A super admin who signed in on this device before the password changed
    // on the server, so the device still holds a hash of the old password.
    await db.insertUser(
      User(
        id: 'boss',
        email: email,
        firstName: 'Boss',
        lastName: 'Admin',
        role: UserRole.superAdmin,
        isActive: true,
        pinEnabled: false,
      ),
      passwordHash: PasswordCrypto.hash(oldPassword),
    );
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('a password the server rejects no longer signs in from the cache', () async {
    mode = _ServerMode.rejectPassword;
    final repo = AuthRepository(db, AuditService(db));

    final result = await repo.beginLogin(email, oldPassword);

    expect(result, isA<LoginFailure>());
    expect((result as LoginFailure).isNetworkError, isFalse);
    expect(await db.getUserPasswordHash('boss'), isNull);
  });

  test('the cached password still works while the server is down', () async {
    mode = _ServerMode.outage;
    final repo = AuthRepository(db, AuditService(db));

    final result = await repo.beginLogin(email, oldPassword);

    expect(result, isA<LoginSuccess>());
    expect(await db.getUserPasswordHash('boss'), isNotNull);
  });

  test('the cached password still works without a connection', () async {
    mode = _ServerMode.dropConnection;
    final repo = AuthRepository(db, AuditService(db));

    final result = await repo.beginLogin(email, oldPassword);

    expect(result, isA<LoginSuccess>());
  });

  test('a wrong password offline is reported as a connection problem', () async {
    mode = _ServerMode.dropConnection;
    final repo = AuthRepository(db, AuditService(db));

    final result = await repo.beginLogin(email, 'Wrong#Pass999');

    expect(result, isA<LoginFailure>());
    expect((result as LoginFailure).isNetworkError, isTrue);
  });
}
