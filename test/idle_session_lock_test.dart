import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/models.dart';
import 'package:medsentry/src/providers/providers.dart';
import 'package:medsentry/src/repositories/auth_repository.dart';
import 'package:medsentry/src/services/audit_service.dart';
import 'package:medsentry/src/widgets/idle_session_lock.dart';

class _RecordingAuth extends AuthRepository {
  _RecordingAuth() : super(SimpleDatabase(), AuditService(SimpleDatabase()));

  int locks = 0;

  @override
  Future<void> lockSession({String? userId}) async => locks++;
}

void main() {
  final user = User(
    id: 'u1',
    clinicId: 'clinic-a',
    email: 'staff@example.com',
    firstName: 'Ana',
    lastName: 'Cruz',
    role: UserRole.staff,
    isActive: true,
    pinEnabled: false,
  );

  Widget app(_RecordingAuth auth, {int timeoutMinutes = 5}) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const IdleSessionLock(child: Text('home')),
        ),
        GoRoute(path: '/login', builder: (_, _) => const Text('login')),
      ],
    );
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        currentUserProvider.overrideWith((ref) => user),
        systemSettingsProvider.overrideWith(
          (ref) async =>
              SystemSettings(sessionTimeoutMinutes: timeoutMinutes),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('locks after the configured inactivity period', (tester) async {
    final auth = _RecordingAuth();
    await tester.pumpWidget(app(auth));
    await tester.pump();

    await tester.pump(const Duration(minutes: 4));
    expect(auth.locks, 0);

    await tester.pump(const Duration(minutes: 1, seconds: 30));
    await tester.pumpAndSettle();
    expect(auth.locks, 1);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('activity postpones the lock', (tester) async {
    final auth = _RecordingAuth();
    await tester.pumpWidget(app(auth));
    await tester.pump();

    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(minutes: 3));
      await tester.tap(find.text('home'));
    }
    // Twelve minutes have passed, never five idle in a row.
    expect(auth.locks, 0);
    expect(find.text('home'), findsOneWidget);
  });
}
