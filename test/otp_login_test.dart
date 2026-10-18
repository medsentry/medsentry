import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/login_challenge.dart';
import 'package:medsentry/src/models/user.dart';
import 'package:medsentry/src/repositories/auth_repository.dart';
import 'package:medsentry/src/repositories/otp_gateway.dart';
import 'package:medsentry/src/services/audit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

class FakeOtpGateway implements OtpGateway {
  final Map<String, String> passwords = {};
  final Map<String, Map<String, dynamic>> profiles = {};
  String validCode = '123456';
  bool offline = false;
  bool _session = false;
  final List<String> sentTo = [];
  int signOutCount = 0;

  @override
  bool get hasSession => _session;

  @override
  Future<String> verifyPassword(String email, String password) async {
    if (offline) throw TimeoutException('offline');
    if (passwords[email] != password) {
      throw const AuthException('Invalid login credentials');
    }
    _session = true;
    return 'auth-$email';
  }

  @override
  Future<void> sendOtp(String email) async => sentTo.add(email);

  @override
  Future<String> verifyOtp(String email, String code) async {
    if (code != validCode) throw const AuthException('Token has expired');
    _session = true;
    return 'auth-$email';
  }

  @override
  Future<void> signOutLocal() async {
    signOutCount++;
    _session = false;
  }

  @override
  Future<Map<String, dynamic>?> fetchProfile(String authUserId) async =>
      profiles[authUserId.replaceFirst('auth-', '')];

  @override
  Future<void> logLoginEvent() async {}
}

User _user(String email, UserRole role, {bool active = true}) {
  final now = DateTime.now();
  return User(
    id: 'id-$email',
    clinicId: role == UserRole.superAdmin ? null : 'clinic-1',
    email: email,
    firstName: 'Test',
    lastName: role.name,
    role: role,
    isActive: active,
    pinEnabled: false,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late Directory tempDir;
  late SimpleDatabase db;
  late FakeOtpGateway gateway;
  late AuthRepository repo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('medsentry_otp_test');
    db = SimpleDatabase();
    await db.useStoreFileForTesting(File('${tempDir.path}/store.json'));
    gateway = FakeOtpGateway();
    repo = AuthRepository(db, AuditService(db), otpGateway: gateway);

    gateway.passwords['staff@example.com'] = 'Secret123!';
    gateway.profiles['staff@example.com'] = _user(
      'staff@example.com',
      UserRole.staff,
    ).toJson();
    gateway.passwords['admin@example.com'] = 'Secret123!';
    gateway.profiles['admin@example.com'] = _user(
      'admin@example.com',
      UserRole.admin,
    ).toJson();
    gateway.passwords['boss@example.com'] = 'Secret123!';
    gateway.profiles['boss@example.com'] = _user(
      'boss@example.com',
      UserRole.superAdmin,
    ).toJson();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('role flag: only staff and admin require an email code', () {
    expect(_user('a@x.com', UserRole.staff).requiresEmailOtp, isTrue);
    expect(_user('a@x.com', UserRole.admin).requiresEmailOtp, isTrue);
    expect(_user('a@x.com', UserRole.superAdmin).requiresEmailOtp, isFalse);
  });

  test('staff password login sends a code and opens no session yet', () async {
    final result = await repo.beginLogin('Staff@Example.com ', 'Secret123!');

    expect(result, isA<LoginOtpRequired>());
    final challenge = (result as LoginOtpRequired).challenge;
    expect(challenge.maskedEmail, 's****@example.com');
    expect(gateway.sentTo, ['staff@example.com']);
    expect(gateway.signOutCount, 1, reason: 'temporary session is dropped');
    expect(gateway.hasSession, isFalse);
    expect(await db.getLastUserId(), isNull);
    expect(await db.getUserByEmail('staff@example.com'), isNull);
  });

  test('RHU admin also requires a code', () async {
    final result = await repo.beginLogin('admin@example.com', 'Secret123!');
    expect(result, isA<LoginOtpRequired>());
  });

  test('wrong password never reaches the code step', () async {
    final result = await repo.beginLogin('staff@example.com', 'nope');
    expect(result, isA<LoginFailure>());
    expect(gateway.sentTo, isEmpty);
  });

  test('offline login is refused with a connection message', () async {
    gateway.offline = true;
    final result = await repo.beginLogin('staff@example.com', 'Secret123!');
    expect(result, isA<LoginFailure>());
    expect((result as LoginFailure).isNetworkError, isTrue);
    expect(gateway.sentTo, isEmpty);
  });

  test('the development seed password does not unlock staff or admin', () async {
    await repo.ensureDefaultAccounts();
    expect(await db.getUserByEmail('staff@gmail.com'), isNotNull);

    for (final email in ['staff@gmail.com', 'admin@gmail.com']) {
      final result = await repo.beginLogin(email, 'Password123!');
      expect(result, isA<LoginFailure>(), reason: email);
    }
    expect(await db.getLastUserId(), isNull);
  });

  test('super admin without a local record signs in without a code', () async {
    final result = await repo.beginLogin('boss@example.com', 'Secret123!');
    expect(result, isA<LoginSuccess>());
    expect(gateway.sentTo, isEmpty);
    expect(await db.getLastUserId(), 'id-boss@example.com');
  });

  test('correct code completes login and stores the user', () async {
    final started =
        await repo.beginLogin('staff@example.com', 'Secret123!')
            as LoginOtpRequired;

    final verified = await repo.verifyLoginOtp(started.challenge, '123456');

    expect(verified, isA<OtpVerified>());
    expect((verified as OtpVerified).user.email, 'staff@example.com');
    expect(await db.getLastUserId(), 'id-staff@example.com');
    expect(await db.getUserByEmail('staff@example.com'), isNotNull);
  });

  test('wrong codes use up attempts then force a fresh login', () async {
    final started =
        await repo.beginLogin('staff@example.com', 'Secret123!')
            as LoginOtpRequired;
    var challenge = started.challenge;

    for (var attempt = kOtpMaxAttempts - 1; attempt >= 1; attempt--) {
      final result = await repo.verifyLoginOtp(challenge, '000000');
      expect(result, isA<OtpRejected>());
      final rejected = result as OtpRejected;
      expect(rejected.exhausted, isFalse);
      expect(rejected.challenge!.attemptsLeft, attempt);
      challenge = rejected.challenge!;
    }

    final last = await repo.verifyLoginOtp(challenge, '000000');
    expect((last as OtpRejected).exhausted, isTrue);
    expect(await db.getLastUserId(), isNull);
  });

  test('malformed and expired codes are rejected without a server call', () async {
    final started =
        await repo.beginLogin('staff@example.com', 'Secret123!')
            as LoginOtpRequired;

    final malformed = await repo.verifyLoginOtp(started.challenge, '12ab');
    expect(malformed, isA<OtpRejected>());
    expect((malformed as OtpRejected).challenge!.attemptsLeft, kOtpMaxAttempts);

    final expired = started.challenge.copyWith(
      expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    final result = await repo.verifyLoginOtp(expired, '123456');
    expect(result, isA<OtpRejected>());
    expect(await db.getLastUserId(), isNull);
  });

  test('resend is blocked during cooldown and allowed afterwards', () async {
    final started =
        await repo.beginLogin('staff@example.com', 'Secret123!')
            as LoginOtpRequired;

    final tooSoon = await repo.resendLoginOtp(started.challenge);
    expect(tooSoon, isA<LoginFailure>());
    expect(gateway.sentTo.length, 1);

    final ready = started.challenge.copyWith(
      resendAvailableAt: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    final again = await repo.resendLoginOtp(ready);
    expect(again, isA<LoginOtpRequired>());
    expect(gateway.sentTo.length, 2);
  });

  test('PIN unlock for staff needs a fresh, OTP-verified session', () async {
    // A staff member with a PIN who has never verified an email code.
    final staff = _user('staff@example.com', UserRole.staff).copyWith(
      pinEnabled: true,
      pinHash: 'hash',
    );
    await db.insertUser(staff);
    await db.setLastUserId(staff.id);
    gateway.profiles['staff@example.com'] = staff.toJson();

    expect(await repo.isPinLoginAvailable(), isFalse);

    // After a real OTP login the unlock path opens up again.
    final started =
        await repo.beginLogin('staff@example.com', 'Secret123!')
            as LoginOtpRequired;
    await repo.verifyLoginOtp(started.challenge, '123456');
    expect(await repo.isPinLoginAvailable(), isTrue);

    // ...but not once the trust window has passed.
    await db.setOtpVerifiedAt(
      DateTime.now().subtract(kOtpTrustWindow + const Duration(minutes: 1)),
    );
    expect(await repo.isPinLoginAvailable(), isFalse);
  });

  test('lockSession clears active session, marks session locked, and preserves last user ID', () async {
    final staff = _user('nurse@example.com', UserRole.staff).copyWith(
      pinEnabled: true,
      pinHash: 'hash',
    );
    await db.insertUser(staff);
    gateway.passwords['nurse@example.com'] = 'Secret123!';
    gateway.profiles['nurse@example.com'] = staff.toJson();

    final started =
        await repo.beginLogin('nurse@example.com', 'Secret123!')
            as LoginOtpRequired;
    await repo.verifyLoginOtp(started.challenge, '123456');

    expect(await repo.isSessionLocked(), isFalse);
    expect(await db.getLastUserId(), staff.id);

    // Now lock session
    await repo.lockSession(userId: staff.id);

    expect(await repo.isSessionLocked(), isTrue);
    expect(await repo.getCurrentUser(), isNull);
    expect(await repo.getLastLoggedInUserEmail(), 'nurse@example.com');
    expect(await repo.isPinLoginAvailable(), isTrue);

    // Unlock session
    await repo.unlockSession();
    expect(await repo.isSessionLocked(), isFalse);
  });

  test('maskEmail hides the local part', () {
    expect(OtpChallenge.maskEmail('jane.doe@gmail.com'), 'j*******@gmail.com');
    expect(OtpChallenge.maskEmail('a@b.co'), 'a@b.co');
  });
}
