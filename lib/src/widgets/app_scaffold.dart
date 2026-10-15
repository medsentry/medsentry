import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/system_settings.dart';
import '../models/user.dart';
import '../services/app_notification.dart';
import '../providers/providers.dart';
import '../utils/date_time_format.dart';
import 'layout/responsive_layout.dart';
import 'medsentry_command_dialog.dart';
import 'system_logo.dart';

class AppNavigationItem {
  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;

  const AppNavigationItem({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });
}

/// Main app scaffold with responsive sidebar, topbar, and drawer
class AppScaffold extends ConsumerStatefulWidget {
  final Widget body;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final int currentIndex;
  final List<AppNavigationItem> navigationItems;
  final Function(int)? onTabChanged;

  const AppScaffold({
    super.key,
    required this.body,
    required this.title,
    required this.navigationItems,
    this.actions,
    this.floatingActionButton,
    this.currentIndex = 0,
    this.onTabChanged,
  });

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  bool _sidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    ServicesBinding.instance.keyboard.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    ServicesBinding.instance.keyboard.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if ((event.logicalKey == LogicalKeyboardKey.keyK ||
              event.logicalKey == LogicalKeyboardKey.keyF) &&
          HardwareKeyboard.instance.isControlPressed) {
        showMedsentryCommandPalette(context, ref);
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final isMobile = ResponsiveLayout.isMobile(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isMobile) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _buildMobileAppBar(context, user, syncStatus),
        drawer: _buildDrawer(context, user, syncStatus),
        body: SafeArea(top: false, child: widget.body),
        floatingActionButton: widget.floatingActionButton,
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(AppDimensions.appBarHeight),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.sidebarBackground : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.borderSubtle : AppColors.lightBorderSubtle,
                width: AppColors.borderWidth,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 800;
                  final spacing = isCompact ? 12.0 : 20.0;

                  return Row(
                    children: [
                      // LEFT ZONE: Brand & Context
                      Flexible(
                        flex: isCompact ? 1 : 0,
                        child: _buildIdentityZone(context),
                      ),
                      SizedBox(width: spacing),

                      // CENTER ZONE: Global Search Bar (Ctrl+K)
                      Expanded(
                        flex: 3,
                        child: _buildSearchZone(
                          context,
                          enabled: user?.canAccessPatientRecords == true,
                        ),
                      ),
                      SizedBox(width: spacing),

                      // RIGHT ZONE: Sync, Clock & Profile
                      Flexible(
                        flex: isCompact ? 1 : 0,
                        child: _buildStatusZone(context, user, syncStatus),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          _buildSidebar(context, forceCollapsed: isTablet),
          VerticalDivider(
            thickness: AppColors.borderWidth,
            width: AppColors.borderWidth,
            color: isDark ? AppColors.borderSubtle : AppColors.lightBorderSubtle,
          ),
          Expanded(child: widget.body),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  PreferredSizeWidget _buildMobileAppBar(
    BuildContext context,
    User? user,
    SyncStatus syncStatus,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();
    final currentPath = GoRouter.maybeOf(context)?.state.uri.path ?? '';
    final isDetailRoute =
        currentPath.startsWith('/patients/') && currentPath != '/patients';

    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? AppColors.sidebarBackground : Colors.white,
      foregroundColor: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
      titleSpacing: 0,
      leading: isDetailRoute
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Patients',
              onPressed: () => context.go('/patients'),
            )
          : Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Open menu',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SystemLogo(
            dataUri: settings.logoDataUri,
            size: 28,
            backgroundColor: isDark
                ? AppColors.primaryEmeraldSubtle
                : AppColors.primaryEmerald.withValues(alpha: 0.15),
            iconColor: AppColors.primaryEmerald,
            iconSize: 18,
            borderRadius: 6,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Search (Ctrl+K)',
          icon: Icon(
            Icons.search,
            size: 20,
            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
          ),
          onPressed: () => showMedsentryCommandPalette(context, ref),
        ),
        _SyncStatusDropdown(status: syncStatus),
        if (user != null) ...[
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: _buildMobileUserAvatar(context, user),
          ),
        ],
      ],
    );
  }

  Widget _buildMobileUserAvatar(BuildContext context, User user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      tooltip: 'Account Menu',
      offset: const Offset(0, 48),
      child: CircleAvatar(
        radius: 15,
        backgroundColor: AppColors.primaryEmeraldSubtle,
        child: Text(
          user.initials,
          style: const TextStyle(
            color: AppColors.primaryEmerald,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                ),
              ),
              Text(
                user.roleDisplay,
                style: TextStyle(
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18),
              SizedBox(width: 8),
              Text('My Profile'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: AppColors.critical, size: 18),
              SizedBox(width: 8),
              Text('Log Out', style: TextStyle(color: AppColors.critical)),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'profile') {
          context.push('/profile');
        } else if (value == 'logout') {
          try {
            await ref.read(authRepositoryProvider).logout();
            ref.read(currentUserProvider.notifier).state = null;
            if (context.mounted) {
              context.go('/login');
            }
          } catch (e) {
            AppNotification.error(title: 'Logout Failed', message: '$e');
          }
        }
      },
    );
  }

  Widget _buildDrawer(BuildContext context, User? user, SyncStatus syncStatus) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();

    return Drawer(
      backgroundColor: isDark ? AppColors.sidebarBackground : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.elevatedSurface : AppColors.lightElevatedSurface,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorderSubtle,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SystemLogo(
                        dataUri: settings.logoDataUri,
                        size: 40,
                        backgroundColor: AppColors.primaryEmeraldSubtle,
                        iconColor: AppColors.primaryEmerald,
                        iconSize: 24,
                        borderRadius: 8,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MedSentry',
                              style: TextStyle(
                                color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              user?.isSuperAdmin == true
                                  ? 'Super Admin Network'
                                  : 'Rural Health Unit',
                              style: TextStyle(
                                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user?.displayName ?? 'User',
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                itemCount: widget.navigationItems.length,
                itemBuilder: (context, index) {
                  final item = widget.navigationItems[index];
                  final selected = widget.currentIndex == index;
                  return _SidebarNavItem(
                    item: item,
                    selected: selected,
                    expanded: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      _onNavigationSelected(index, context);
                    },
                  );
                },
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? AppColors.borderSubtle : AppColors.lightBorderSubtle,
            ),
            ListTile(
              leading: Icon(
                Icons.person_outline,
                size: 20,
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              ),
              title: Text(
                'My Profile',
                style: TextStyle(
                  color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                  fontSize: 14,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.critical, size: 20),
              title: const Text(
                'Log Out',
                style: TextStyle(color: AppColors.critical, fontSize: 14),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  await ref.read(authRepositoryProvider).logout();
                  ref.read(currentUserProvider.notifier).state = null;
                  if (context.mounted) {
                    context.go('/login');
                  }
                } catch (e) {
                  AppNotification.error(title: 'Logout Failed', message: '$e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onNavigationSelected(int index, BuildContext context) {
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(index);
    } else {
      if (index >= 0 && index < widget.navigationItems.length) {
        context.go(widget.navigationItems[index].path);
      }
    }
  }

  Widget _buildSidebar(BuildContext context, {bool forceCollapsed = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isExpanded = !forceCollapsed && _sidebarExpanded;
    final width = isExpanded
        ? AppDimensions.sidebarExpanded
        : AppDimensions.sidebarCollapsed;

    return AnimatedContainer(
      duration: AppDurations.normal,
      curve: Curves.easeInOut,
      width: width,
      color: isDark ? AppColors.sidebarBackground : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              itemCount: widget.navigationItems.length,
              itemBuilder: (context, index) {
                final item = widget.navigationItems[index];
                final selected = widget.currentIndex == index;
                return _SidebarNavItem(
                  item: item,
                  selected: selected,
                  expanded: isExpanded,
                  onTap: () => _onNavigationSelected(index, context),
                );
              },
            ),
          ),
          if (!forceCollapsed) ...[
            Divider(
              height: 1,
              color: isDark ? AppColors.borderSubtle : AppColors.lightBorderSubtle,
            ),
            _buildSidebarToggle(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarToggle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = _sidebarExpanded ? 'Collapse sidebar' : 'Expand sidebar';

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: _sidebarExpanded
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: [
              if (_sidebarExpanded)
                Text(
                  'Collapse',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              AnimatedRotation(
                turns: _sidebarExpanded ? 0 : 0.5,
                duration: AppDurations.normal,
                child: Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// LEFT ZONE: Brand & Context
  Widget _buildIdentityZone(BuildContext context) {
    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SystemLogo(
          dataUri: settings.logoDataUri,
          size: 36,
          backgroundColor: isDark
              ? AppColors.primaryEmeraldSubtle
              : AppColors.primaryEmerald.withValues(alpha: 0.15),
          iconColor: AppColors.primaryEmerald,
          iconSize: 22,
          borderRadius: 8,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MedSentry',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                ref.watch(currentUserProvider)?.isSuperAdmin == true
                    ? 'Super Admin • All RHUs'
                    : 'Rural Health Unit',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// CENTER ZONE: Global Search Bar (Ctrl+K)
  Widget _buildSearchZone(BuildContext context, {required bool enabled}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: AppRadius.roundedSm,
      onTap: enabled ? () => showMedsentryCommandPalette(context, ref) : null,
      child: Container(
        height: 38,
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.inputSurface : AppColors.lightInputSurface,
          borderRadius: AppRadius.roundedSm,
          border: Border.all(
            color: isDark ? AppColors.border : AppColors.lightBorder,
            width: AppColors.borderWidth,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              size: 16,
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Search patients, records, or jump to page...',
                style: TextStyle(
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.elevatedSurface : AppColors.lightElevatedSurface,
                borderRadius: AppRadius.roundedXs,
                border: Border.all(
                  color: isDark ? AppColors.borderSubtle : AppColors.lightBorderSubtle,
                ),
              ),
              child: Text(
                'Ctrl + K',
                style: TextStyle(
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// RIGHT ZONE: Status, Clock & Profile
  Widget _buildStatusZone(
    BuildContext context,
    User? user,
    SyncStatus syncStatus,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 320;
        final hideClock = constraints.maxWidth < 220;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PWA Install Action if running on web and installable
            Consumer(
              builder: (context, ref, _) {
                final installer = ref.watch(pwaInstallerProvider);
                if (!installer.isSupported || installer.isInstalled) {
                  return const SizedBox.shrink();
                }
                return StreamBuilder<bool>(
                  stream: installer.onInstallableChanged,
                  initialData: installer.canInstall,
                  builder: (context, snapshot) {
                    final canInstall = snapshot.data ?? installer.canInstall;
                    if (!canInstall) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        tooltip: 'Install MedSentry to Device',
                        icon: Icon(
                          Icons.install_desktop_outlined,
                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          size: 18,
                        ),
                        onPressed: () async {
                          final installed = await installer.promptInstall();
                          if (installed) {
                            AppNotification.success(
                              title: 'Installation Started',
                              message:
                                  'MedSentry is being installed to your device.',
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),

            // Sync Status with Dropdown
            _SyncStatusDropdown(status: syncStatus),

            if (!hideClock) ...[
              SizedBox(width: isCompact ? 10 : 16),
              // Live Clock
              StreamBuilder<DateTime>(
                stream: Stream.periodic(
                  const Duration(seconds: 1),
                  (_) => DateTime.now(),
                ),
                builder: (context, snapshot) {
                  final now = snapshot.data ?? DateTime.now();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatTime12h(now),
                        style: TextStyle(
                          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!isCompact)
                        Text(
                          _formatDate(now),
                          style: TextStyle(
                            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],

            SizedBox(width: isCompact ? 10 : 16),

            // User Profile
            if (user != null)
              PopupMenuButton<String>(
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.roundedMd,
                  side: BorderSide(
                    color: isDark ? AppColors.border : AppColors.lightBorder,
                    width: AppColors.borderWidth,
                  ),
                ),
                color: isDark ? AppColors.elevatedSurface : AppColors.lightElevatedSurface,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryEmeraldSubtle,
                      radius: 16,
                      child: Text(
                        user.initials.isNotEmpty ? user.initials : 'U',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryEmerald,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (!isCompact) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              user.roleDisplay,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    ),
                  ],
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'lock',
                    child: Row(
                      children: const [
                        Icon(Icons.lock_outline, color: AppColors.pending, size: 18),
                        SizedBox(width: 8),
                        Text('Lock Screen'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 18),
                        SizedBox(width: 8),
                        Text('My Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: AppColors.critical, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Log Out',
                          style: TextStyle(color: AppColors.critical),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  switch (value) {
                    case 'lock':
                      final user = ref.read(currentUserProvider);
                      await ref
                          .read(authRepositoryProvider)
                          .lockSession(userId: user?.id);
                      ref.read(currentUserProvider.notifier).state = null;
                      if (context.mounted) {
                        context.go('/login?locked=1');
                      }
                      break;
                    case 'profile':
                      context.push('/profile');
                      break;
                    case 'logout':
                      try {
                        await ref.read(authRepositoryProvider).logout();
                        ref.read(currentUserProvider.notifier).state = null;
                        AppNotification.success(
                          title: 'Logout Successful',
                          message: 'You have safely closed your session.',
                        );
                        if (context.mounted) {
                          context.go('/login');
                        }
                      } catch (e) {
                        AppNotification.error(
                          title: 'Logout Failed',
                          message: 'An error occurred while logging out: $e',
                        );
                      }
                      break;
                  }
                },
              ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }
}

class _SidebarNavItem extends StatelessWidget {
  final AppNavigationItem item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final background = selected
        ? AppColors.primaryEmeraldSubtle
        : Colors.transparent;

    final foreground = selected
        ? AppColors.primaryEmerald
        : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary);

    final content = Material(
      color: background,
      borderRadius: AppRadius.roundedSm,
      child: InkWell(
        borderRadius: AppRadius.roundedSm,
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        hoverColor: isDark
            ? AppColors.elevatedSurface.withValues(alpha: 0.5)
            : AppColors.lightElevatedSurface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 0,
              vertical: 8,
            ),
            child: expanded
                ? Row(
                    children: [
                      Icon(
                        selected ? item.selectedIcon : item.icon,
                        size: 19,
                        color: foreground,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: foreground,
                          ),
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 3,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.primaryEmerald,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Icon(
                      selected ? item.selectedIcon : item.icon,
                      size: 20,
                      color: foreground,
                    ),
                  ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: expanded ? content : Tooltip(message: item.label, child: content),
    );
  }
}

/// Sync status dropdown widget with detailed status info
class _SyncStatusDropdown extends ConsumerWidget {
  final SyncStatus status;

  const _SyncStatusDropdown({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color color;
    String statusText;
    IconData icon;

    switch (status) {
      case SyncStatus.synced:
        color = AppColors.success;
        statusText = 'Online & Synced';
        icon = Icons.cloud_done_outlined;
        break;
      case SyncStatus.syncing:
        color = AppColors.info;
        statusText = 'Syncing...';
        icon = Icons.sync;
        break;
      case SyncStatus.pending:
        color = AppColors.pending;
        statusText = 'Pending Sync';
        icon = Icons.cloud_upload_outlined;
        break;
      case SyncStatus.error:
        color = AppColors.critical;
        statusText = 'Sync Error';
        icon = Icons.error_outline;
        break;
      case SyncStatus.offline:
        color = AppColors.neutral;
        statusText = 'Offline Mode';
        icon = Icons.cloud_off_outlined;
        break;
    }

    return PopupMenuButton<String>(
      tooltip: 'Sync: $statusText',
      offset: const Offset(0, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.roundedSm,
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'sync_now',
          child: Row(
            children: [
              Icon(Icons.sync, size: 18),
              SizedBox(width: 8),
              Text('Sync Now', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'sync_settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18),
              SizedBox(width: 8),
              Text('Sync Settings', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'sync_now':
            AppNotification.info(
              title: 'Syncing',
              message: 'Starting cloud sync...',
            );
            ref.read(syncServiceProvider).startSync();
            break;
          case 'sync_settings':
            context.push('/settings?tab=sync');
            break;
        }
      },
    );
  }
}
