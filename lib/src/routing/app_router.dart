import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/login_screen.dart';
import '../screens/patient_detail_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/patients_screen.dart';
import '../screens/documents_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/staff_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/audit_logs_screen.dart';
import '../screens/archive_screen.dart';
import '../screens/certificates_screen.dart';
import '../screens/sync_screen.dart';
import '../screens/rhu_management_screen.dart';
import '../widgets/app_shell.dart';
import '../providers/providers.dart';
import '../models/user.dart';

bool _canAccessRoute(User user, String path) {
  if (path == '/profile') return true;
  if (path == '/dashboard') return true;
  if (path.startsWith('/rhus')) return user.isSuperAdmin;
  if (path.startsWith('/settings')) return user.canAccessSettings;
  if (path.startsWith('/staff')) return user.canManageStaffAccounts;
  if (path.startsWith('/audit-logs')) return user.canViewAuditLogs;
  if (path.startsWith('/archive')) return user.canManageArchive;
  if (path.startsWith('/sync')) return user.canSyncRecords;
  if (path.startsWith('/certificates')) return user.canGenerateCertificates;
  if (path.startsWith('/reports')) return user.canGenerateReports;
  if (path.startsWith('/documents')) return user.canManageDocuments;
  if (path.startsWith('/patients')) return user.canAccessPatientRecords;
  return true;
}

class _RouterRefreshListenable extends ChangeNotifier {
  void trigger() => notifyListeners();
}

Page<void> _noTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

// Router provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _RouterRefreshListenable();
  ref.listen<User?>(currentUserProvider, (_, _) => refreshListenable.trigger());
  ref.listen(systemSettingsProvider, (_, _) => refreshListenable.trigger());
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshListenable,
    redirect: (context, state) async {
      try {
        var currentUser = ref.read(currentUserProvider);
        final isLoginRoute = state.uri.path == '/login';

        if (currentUser == null) {
          currentUser = await ref
              .read(authRepositoryProvider)
              .getCurrentUser()
              .timeout(const Duration(seconds: 8));
          if (currentUser != null) {
            ref.read(currentUserProvider.notifier).state = currentUser;
          }
        }

        if (currentUser != null && !currentUser.isActive) {
          await ref.read(authRepositoryProvider).logout();
          ref.read(currentUserProvider.notifier).state = null;
          currentUser = null;
        }

        if (currentUser == null && !isLoginRoute) {
          return '/login';
        }

        if (currentUser != null && (isLoginRoute || state.uri.path == '/')) {
          return currentUser.homePath;
        }

        if (currentUser != null && !isLoginRoute) {
          final targetPath = state.uri.path;
          final requiresModuleSettings =
              targetPath.startsWith('/certificates') ||
              targetPath.startsWith('/sync');
          var moduleAccessAllowed = true;
          if (requiresModuleSettings) {
            final settings = await ref
                .read(systemSettingsProvider.future)
                .timeout(const Duration(seconds: 5));
            moduleAccessAllowed =
                !((targetPath.startsWith('/certificates') &&
                        !settings.certificatesModuleEnabled) ||
                    (targetPath.startsWith('/sync') &&
                        !settings.syncModuleEnabled));
          }

          if (!moduleAccessAllowed ||
              !_canAccessRoute(currentUser, targetPath)) {
            return currentUser.homePath;
          }
        }

        return null;
      } catch (e, st) {
        debugPrint('AppRouter redirect error: $e\n$st');
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null && state.uri.path == currentUser.homePath) {
          return null;
        }
        if (currentUser != null) return currentUser.homePath;
        return state.uri.path == '/login' ? null : '/login';
      }
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) =>
            ref.read(currentUserProvider)?.homePath ?? '/login',
      ),
      GoRoute(path: '/queue', redirect: (context, state) => '/patients'),
      GoRoute(
        path: '/queue/:id/soap',
        redirect: (context, state) => '/patients/${state.pathParameters['id']}',
      ),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rhus',
                name: 'rhus',
                pageBuilder: (context, state) => _noTransitionPage(
                  state: state,
                  child: const RhuManagementScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF080909),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF87171).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 36,
                  color: Color(0xFFF87171),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Page Not Found or Navigation Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF3F4F6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                state.error?.toString() ??
                    'The requested page could not be located.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  final user = ref.read(currentUserProvider);
                  context.go(user?.homePath ?? '/login');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF34D399),
                  foregroundColor: const Color(0xFF080909),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text(
                  'Return to Application',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
