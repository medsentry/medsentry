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
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  );

  static const _patientsNavigationItem = AppNavigationItem(
    label: 'Patients',
    path: '/patients',
    icon: Icons.people_outlined,
    selectedIcon: Icons.people,
  );

  static const _queueNavigationItem = AppNavigationItem(
    label: 'Queue',
    path: '/queue',
    icon: Icons.queue_outlined,
    selectedIcon: Icons.queue,
  );

  static const _documentsNavigationItem = AppNavigationItem(
    label: 'Documents',
    path: '/documents',
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder,
  );

  static const _certificatesNavigationItem = AppNavigationItem(
    label: 'Certificates',
    path: '/certificates',
    icon: Icons.description_outlined,
    selectedIcon: Icons.description,
  );

  static const _reportsNavigationItem = AppNavigationItem(
    label: 'Reports',
    path: '/reports',
    icon: Icons.assessment_outlined,
    selectedIcon: Icons.assessment,
  );

  static const _auditNavigationItem = AppNavigationItem(
    label: 'Audit Logs',
    path: '/audit-logs',
    icon: Icons.history_outlined,
    selectedIcon: Icons.history,
  );

  static const _archiveNavigationItem = AppNavigationItem(
    label: 'Archive',
    path: '/archive',
    icon: Icons.archive_outlined,
    selectedIcon: Icons.archive,
  );

  static const _syncNavigationItem = AppNavigationItem(
    label: 'Sync',
    path: '/sync',
    icon: Icons.cloud_sync_outlined,
    selectedIcon: Icons.cloud_sync,
  );

  static const _staffNavigationItem = AppNavigationItem(
    label: 'Users',
    path: '/staff',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
  );

  static const _settingsNavigationItem = AppNavigationItem(
    label: 'Settings',
    path: '/settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  );

  static const _rhuNavigationItem = AppNavigationItem(
    label: 'RHU Units',
    path: '/rhus',
    icon: Icons.domain_outlined,
    selectedIcon: Icons.domain,
  );

  static const _fallbackNavigationItems = [_dashboardNavigationItem];

  /// Super Admin: Dashboard, RHUs, Staff, Reports, Audit Logs, Settings
  static const _superAdminNavigationItems = [
    _dashboardNavigationItem,
    _rhuNavigationItem,
    _staffNavigationItem,
    _reportsNavigationItem,
    _auditNavigationItem,
    _settingsNavigationItem,
  ];

  /// Admin: Dashboard, Patients, Documents, Reports, Audit, Archive, Staff, Settings
  static const _adminNavigationItems = [
    _dashboardNavigationItem,
    _patientsNavigationItem,
    _documentsNavigationItem,
    _reportsNavigationItem,
    _auditNavigationItem,
    _archiveNavigationItem,
    _staffNavigationItem,
    _settingsNavigationItem,
  ];

  /// Staff: Dashboard, Patients, Queue, Documents, Certificates, Reports, Sync
  static const _staffNavigationItems = [
    _dashboardNavigationItem,
    _patientsNavigationItem,
    _queueNavigationItem,
    _documentsNavigationItem,
    _certificatesNavigationItem,
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
      if (item.path == '/queue') {
        return settings.queueModuleEnabled;
      }
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
    final index = items.indexWhere((item) => path.startsWith(item.path));
    return index == -1 ? 0 : index;
  }

  /// Maps sidebar destinations to [StatefulShellRoute] branch indices.
  int _branchIndexForPath(String path) {
    if (path.startsWith('/rhus')) return 12;
    if (path.startsWith('/patients')) return 1;
    if (path.startsWith('/queue')) return 2;
    if (path.startsWith('/documents')) return 3;
    if (path.startsWith('/certificates')) return 4;
    if (path.startsWith('/reports')) return 5;
    if (path.startsWith('/audit-logs')) return 6;
    if (path.startsWith('/archive')) return 7;
    if (path.startsWith('/sync')) return 8;
    if (path.startsWith('/staff')) return 9;
    if (path.startsWith('/settings')) return 10;
    if (path.startsWith('/profile')) return 11;
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

    final title = navigationItems[currentIndex].label;

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
