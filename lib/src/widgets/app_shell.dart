import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/system_settings.dart';
import '../models/user.dart';
import '../providers/providers.dart';
import '../widgets/app_scaffold.dart';

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _dashboardNavigationItem = AppNavigationItem(
    label: 'Dashboard',
    path: '/dashboard',
    icon: Icons.grid_view_rounded,
    selectedIcon: Icons.grid_view_rounded,
    group: 'OVERVIEW',
  );

  static const _patientsNavigationItem = AppNavigationItem(
    label: 'Patients',
    path: '/patients',
    icon: Icons.people_outline_rounded,
    selectedIcon: Icons.people_rounded,
    group: 'OVERVIEW',
  );

  static const _documentsNavigationItem = AppNavigationItem(
    label: 'Documents',
    path: '/documents',
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder_rounded,
    group: 'OPERATIONS',
  );

  static const _certificatesNavigationItem = AppNavigationItem(
    label: 'Certificates',
    path: '/certificates',
    icon: Icons.description_outlined,
    selectedIcon: Icons.description_rounded,
    group: 'OVERVIEW',
  );

  static const _reportsNavigationItem = AppNavigationItem(
    label: 'Reports',
    path: '/reports',
    icon: Icons.insert_chart_outlined_rounded,
    selectedIcon: Icons.insert_chart_rounded,
    group: 'ANALYTICS',
  );

  static const _auditNavigationItem = AppNavigationItem(
    label: 'Audit Logs',
    path: '/audit-logs',
    icon: Icons.shield_outlined,
    selectedIcon: Icons.shield_rounded,
    group: 'ANALYTICS',
  );

  static const _archiveNavigationItem = AppNavigationItem(
    label: 'Archive',
    path: '/archive',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    group: 'OPERATIONS',
  );

  static const _syncNavigationItem = AppNavigationItem(
    label: 'Cloud Sync',
    path: '/sync',
    icon: Icons.cloud_sync_outlined,
    selectedIcon: Icons.cloud_sync_rounded,
    group: 'OPERATIONS',
  );

  static const _staffNavigationItem = AppNavigationItem(
    label: 'Staff',
    path: '/staff',
    icon: Icons.manage_accounts_outlined,
    selectedIcon: Icons.manage_accounts_rounded,
    group: 'OPERATIONS',
  );

  static const _rhuNavigationItem = AppNavigationItem(
    label: 'RHU Units',
    path: '/rhus',
    icon: Icons.domain_outlined,
    selectedIcon: Icons.domain_rounded,
    group: 'OPERATIONS',
  );

  static const _fallbackNavigationItems = [_dashboardNavigationItem];

  /// Super Admin: Dashboard, Patients, RHU Units, Staff, Documents, Certificates, Reports, Audit Logs, Archive, Cloud Sync
  static const _superAdminNavigationItems = [
    _dashboardNavigationItem,
    _patientsNavigationItem,
    _rhuNavigationItem,
    _staffNavigationItem,
    _documentsNavigationItem,
    _certificatesNavigationItem,
    _reportsNavigationItem,
    _auditNavigationItem,
    _archiveNavigationItem,
    _syncNavigationItem,
  ];

  /// Admin: Dashboard, Patients, Certificates, Documents, Reports, Audit, Archive, Staff, Cloud Sync
  static const _adminNavigationItems = [
    _dashboardNavigationItem,
    _patientsNavigationItem,
    _certificatesNavigationItem,
    _documentsNavigationItem,
    _reportsNavigationItem,
    _auditNavigationItem,
    _archiveNavigationItem,
    _staffNavigationItem,
    _syncNavigationItem,
  ];

  /// Staff: Dashboard, Patients, Certificates, Documents, Reports, Cloud Sync
  static const _staffNavigationItems = [
    _dashboardNavigationItem,
    _patientsNavigationItem,
    _certificatesNavigationItem,
    _documentsNavigationItem,
    _reportsNavigationItem,
    _syncNavigationItem,
  ];

  List<AppNavigationItem> _navigationItems(User? user) {
    if (user == null) return _fallbackNavigationItems;
    if (user.isSuperAdmin) return _superAdminNavigationItems;
    if (user.isAdmin) return _adminNavigationItems;
    if (user.role == UserRole.staff) return _staffNavigationItems;

    return _staffNavigationItems;
  }

  List<AppNavigationItem> _applyClinicModules(
    List<AppNavigationItem> items,
    SystemSettings? settings,
  ) {
    if (settings == null) return items;
    return items.where((item) {
      if (item.path == '/certificates') {
        return settings.certificatesModuleEnabled;
      }
      if (item.path == '/sync') {
        return settings.syncModuleEnabled;
      }
      return true;
    }).toList();
  }

  int _getTabIndexFromPath(String path, List<AppNavigationItem> items) {
    return items.indexWhere((item) => path.startsWith(item.path));
  }

  /// Maps sidebar destinations to [StatefulShellRoute] branch indices.
  int _branchIndexForPath(String path) {
    if (path.startsWith('/rhus')) return 11;
    if (path.startsWith('/patients')) return 1;
    if (path.startsWith('/documents')) return 2;
    if (path.startsWith('/certificates')) return 3;
    if (path.startsWith('/reports')) return 4;
    if (path.startsWith('/audit-logs')) return 5;
    if (path.startsWith('/archive')) return 6;
    if (path.startsWith('/sync')) return 7;
    if (path.startsWith('/staff')) return 8;
    if (path.startsWith('/settings')) return 9;
    if (path.startsWith('/profile')) return 10;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final clinicSettings = ref.watch(systemSettingsProvider).valueOrNull;
    final navigationItems = _applyClinicModules(
      _navigationItems(user),
      clinicSettings,
    );
    final currentPath = GoRouter.of(context).state.uri.path;
    final currentIndex = _getTabIndexFromPath(currentPath, navigationItems);

    final title = currentIndex >= 0 && currentIndex < navigationItems.length
        ? navigationItems[currentIndex].label
        : currentPath.startsWith('/profile')
        ? 'My Profile'
        : currentPath.startsWith('/sync')
        ? 'Cloud Sync'
        : 'Dashboard';

    return AppScaffold(
      title: title,
      currentIndex: currentIndex,
      navigationItems: navigationItems,
      onTabChanged: (index) {
        if (index < 0 || index >= navigationItems.length) return;

        final target = navigationItems[index].path;
        if (target == currentPath) return;

        final branchIndex = _branchIndexForPath(target);
        if (branchIndex == widget.navigationShell.currentIndex) {
          GoRouter.of(context).go(target);
          return;
        }

        widget.navigationShell.goBranch(branchIndex, initialLocation: true);
      },
      body: widget.navigationShell,
    );
  }
}
