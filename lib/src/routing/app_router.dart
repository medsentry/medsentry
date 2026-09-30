import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/login_screen.dart';
import '../screens/patient_detail_screen.dart';
import '../screens/consultation_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/patients_screen.dart';
import '../screens/queue_screen.dart';
import '../screens/documents_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/staff_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/audit_logs_screen.dart';
import '../screens/archive_screen.dart';
import '../screens/certificates_screen.dart';
import '../screens/sync_screen.dart';
import '../widgets/app_shell.dart';
import '../providers/providers.dart';
import '../models/user.dart';

bool _canAccessRoute(User user, String path) {
  if (path == '/dashboard' || path == '/profile') return true;
  if (path.startsWith('/settings')) return user.canManageSystemData;
  if (path.startsWith('/staff')) return user.canManageSystemData;
  if (path.startsWith('/audit-logs')) return user.canViewAuditLogs;
  if (path.startsWith('/archive')) return user.canManageArchive;
  if (path.startsWith('/sync')) return user.canSyncRecords;
  if (path.startsWith('/certificates')) return user.canGenerateCertificates;
  if (path.startsWith('/reports')) return user.canGenerateReports;
  if (path.startsWith('/documents')) return user.canManageDocuments;
  if (path.startsWith('/patients')) return user.canAccessPatientRecords;
  if (path.startsWith('/queue/') && path.endsWith('/soap')) {
    return user.canConsult;
  }
  if (path.startsWith('/queue')) return user.canViewQueue;
  return true;
}

Page<void> _noTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

// Router provider
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      try {
        var currentUser = ref.read(currentUserProvider);
        final isLoginRoute = state.uri.path == '/login';

        if (currentUser == null) {
          currentUser = await ref.read(authRepositoryProvider).getCurrentUser();
          if (currentUser != null) {
            ref.read(currentUserProvider.notifier).state = currentUser;
          }
        }

        if (currentUser == null && !isLoginRoute) {
          return '/login';
        }

        if (currentUser != null && isLoginRoute) {
          return currentUser.homePath;
        }

        if (currentUser != null &&
            !isLoginRoute &&
            !_canAccessRoute(currentUser, state.uri.path)) {
          return currentUser.homePath;
        }

        return null;
      } catch (e, st) {
        debugPrint('AppRouter redirect error: $e\n$st');
        return '/login';
      }
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) =>
            LoginScreen(locked: state.uri.queryParameters['locked'] == '1'),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                pageBuilder: (context, state) => _noTransitionPage(
                  state: state,
                  child: const DashboardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patients',
                name: 'patients',
                pageBuilder: (context, state) => _noTransitionPage(
                  state: state,
                  child: PatientsScreen(
                    openAddPatient:
                        state.uri.queryParameters['action'] == 'add-patient',
                    initialSearch: state.uri.queryParameters['search'],
                  ),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'patient_detail',
                    builder: (context, state) {
                      final patientId = state.pathParameters['id']!;
                      return PatientDetailScreen(patientId: patientId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/queue',
                name: 'queue',
                pageBuilder: (context, state) =>
                    _noTransitionPage(state: state, child: const QueueScreen()),
                routes: [
                  GoRoute(
                    path: ':id/soap',
                    name: 'consultation',
                    builder: (context, state) {
                      final queueId = state.pathParameters['id']!;
                      return ConsultationScreen(queueId: queueId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/documents',
                name: 'documents',
                pageBuilder: (context, state) => _noTransitionPage(
                  state: state,
                  child: const DocumentsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/certificates',
                name: 'certificates',
                pageBuilder: (context, state) => _noTransitionPage(
                  state: state,
                  child: const CertificatesScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                name: 'reports',
                pageBuilder: (context, state) => _noTransitionPage(
                  state: state,
                  child: const ReportsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/audit-logs',
                name: 'audit_logs',
                pageBuilder: (context, state) => _noTransitionPage(
                  state: state,
                  child: const AuditLogsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/archive',
                name: 'archive',
                pageBuilder: (context, state) => _noTransitionPage(
                  state: state,
                  child: const ArchiveScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sync',
                name: 'sync',
                pageBuilder: (context, state) =>
                    _noTransitionPage(state: state, child: const SyncScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/staff',
                name: 'staff',
                pageBuilder: (context, state) =>
                    _noTransitionPage(state: state, child: const StaffScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                pageBuilder: (context, state) => _noTransitionPage(
                  state: state,
                  child: const SettingsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                pageBuilder: (context, state) => _noTransitionPage(
                  state: state,
                  child: const ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Error: ${state.error}'))),
  );
});
