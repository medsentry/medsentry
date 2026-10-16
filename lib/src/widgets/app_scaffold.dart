import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/system_settings.dart';
import '../models/user.dart';
import '../services/app_notification.dart';
import '../providers/providers.dart';
import 'package:intl/intl.dart';
import 'layout/responsive_layout.dart';
import 'medsentry_command_dialog.dart';
import 'system_logo.dart';
import 'user_avatar.dart';

class AppNavigationItem {
  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String? group;
  final int? badgeCount;
  final Color? badgeColor;

  const AppNavigationItem({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
    this.group,
    this.badgeCount,
    this.badgeColor,
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
      body: Row(
        children: [
          _buildSidebar(context, forceCollapsed: isTablet),
          VerticalDivider(
            thickness: AppColors.borderWidth,
            width: AppColors.borderWidth,
            color: isDark
                ? AppColors.borderSubtle
                : AppColors.lightBorderSubtle,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDesktopHeader(context, user, syncStatus),
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  Widget _buildDesktopHeader(
    BuildContext context,
    User? user,
    SyncStatus syncStatus,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 72.0,
      decoration: BoxDecoration(
        color: isDark ? AppColors.sidebarBackground : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.borderSubtle
                : AppColors.lightBorderSubtle,
            width: AppColors.borderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            // LEFT ZONE: Dynamic Greeting / Title + Live Monitoring Pill + Subtitle
            Expanded(child: _buildGreetingZone(context, user)),
            const SizedBox(width: 16),

            // RIGHT ZONE: Search Pill + Notification Bell + Sync
            _buildHeaderActionsZone(context, user, syncStatus),
          ],
        ),
      ),
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
      foregroundColor: isDark
          ? AppColors.textPrimary
          : AppColors.lightTextPrimary,
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
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.lightTextPrimary,
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
            color: isDark
                ? AppColors.textSecondary
                : AppColors.lightTextSecondary,
          ),
          onPressed: () => showMedsentryCommandPalette(context, ref),
        ),
        _SyncStatusDropdown(status: syncStatus),
        if (user != null) ...[
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: _buildProfileButton(context, user, compact: true),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileButton(
    BuildContext context,
    User user, {
    bool compact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'My Profile',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/profile'),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 0 : 8,
              vertical: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(user: user, radius: 16),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  Text(
                    user.displayName,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
                color: isDark
                    ? AppColors.elevatedSurface
                    : AppColors.lightElevatedSurface,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? AppColors.borderSubtle
                        : AppColors.lightBorderSubtle,
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
                                color: isDark
                                    ? AppColors.textPrimary
                                    : AppColors.lightTextPrimary,
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
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary,
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
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.lightTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
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
              color: isDark
                  ? AppColors.borderSubtle
                  : AppColors.lightBorderSubtle,
            ),
            ListTile(
              leading: const Icon(
                Icons.logout,
                color: AppColors.critical,
                size: 20,
              ),
              title: const Text(
                'Log Out',
                style: TextStyle(color: AppColors.critical, fontSize: 14),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                await _logout(context);
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
    final width = isExpanded ? 236.0 : AppDimensions.sidebarCollapsed;
    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();
    // Group the navigation items
    final groups = <String, List<_IndexedNavItem>>{};
    for (int i = 0; i < widget.navigationItems.length; i++) {
      final item = widget.navigationItems[i];
      final groupName = item.group ?? 'OVERVIEW';
      groups.putIfAbsent(groupName, () => []).add(_IndexedNavItem(i, item));
    }

    return AnimatedContainer(
      duration: AppDurations.normal,
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        color: isDark ? AppColors.sidebarBackground : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark
                ? AppColors.borderSubtle
                : AppColors.lightBorderSubtle,
            width: AppColors.borderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar Top Brand Box
          _buildSidebarBrand(context, isExpanded, settings),

          // Categorized Navigation Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              children: [
                for (final entry in groups.entries) ...[
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 8),
                  for (final indexedItem in entry.value)
                    _SidebarNavItem(
                      item: indexedItem.item,
                      selected: widget.currentIndex == indexedItem.index,
                      expanded: isExpanded,
                      onTap: () =>
                          _onNavigationSelected(indexedItem.index, context),
                    ),
                ],
              ],
            ),
          ),

          _buildSidebarLogout(context, isExpanded),

          if (!forceCollapsed) ...[
            Divider(
              height: 1,
              color: isDark
                  ? AppColors.borderSubtle
                  : AppColors.lightBorderSubtle,
            ),
            _buildSidebarToggle(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarBrand(
    BuildContext context,
    bool isExpanded,
    SystemSettings settings,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isExpanded ? 16 : 12,
        vertical: 18,
      ),
      child: Align(
        alignment: isExpanded ? Alignment.centerLeft : Alignment.center,
        child: Tooltip(
          message: 'MedSentry Clinical System',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.go('/'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16171D) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF262936)
                      : AppColors.lightBorder,
                  width: 1.2,
                ),
                boxShadow: isDark ? AppShadows.subtle : null,
              ),
              child: Center(
                child: SystemLogo(
                  dataUri: settings.logoDataUri,
                  size: 26,
                  backgroundColor: Colors.transparent,
                  iconColor: AppColors.primaryEmerald,
                  iconSize: 22,
                  borderRadius: 4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarLogout(BuildContext context, bool isExpanded) {
    return Tooltip(
      message: 'Log Out',
      child: InkWell(
        onTap: () => _logout(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout, color: AppColors.critical, size: 20),
              if (isExpanded) ...[
                const SizedBox(width: 12),
                const Text(
                  'Log Out',
                  style: TextStyle(
                    color: AppColors.critical,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await ref.read(authRepositoryProvider).logout();
      ref.read(currentUserProvider.notifier).state = null;
      if (context.mounted) context.go('/login');
    } catch (e) {
      AppNotification.error(title: 'Logout Failed', message: '$e');
    }
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
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              AnimatedRotation(
                turns: _sidebarExpanded ? 0 : 0.5,
                duration: AppDurations.normal,
                child: Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 18) return '☀️';
    return '🌙';
  }

  String _getUserGreetingName(User? user) {
    if (user == null) return 'Dr. Rivera';
    if (user.displayName.isNotEmpty) {
      if (user.displayName.toLowerCase().startsWith('dr.') ||
          user.displayName.toLowerCase().startsWith('dr ')) {
        return user.displayName;
      }
      return 'Dr. ${user.lastName.isNotEmpty ? user.lastName : user.displayName}';
    }
    return 'Dr. Rivera';
  }

  Widget _buildGreetingZone(BuildContext context, User? user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();

    final isDashboard = widget.title == 'Dashboard' || widget.title.isEmpty;
    final timeGreeting = _getTimeGreeting();
    final greetingIcon = _getGreetingIcon();
    final userName = _getUserGreetingName(user);
    final greetingTitle = isDashboard
        ? '$timeGreeting, $userName $greetingIcon'
        : widget.title;

    final dateStr = DateFormat('EEEE, d MMMM y').format(DateTime.now());
    final facility = settings.clinicName.isNotEmpty
        ? settings.clinicName
        : 'Ward 4B — Cardiology';
    final subtitle = '$dateStr · $facility';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                greetingTitle,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryEmerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Live Monitoring',
                    style: TextStyle(
                      color: AppColors.primaryEmerald,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.textSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderActionsZone(
    BuildContext context,
    User? user,
    SyncStatus syncStatus,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pill Search Bar (Ctrl+K)
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: user?.canAccessPatientRecords == true
              ? () => showMedsentryCommandPalette(context, ref)
              : null,
          child: Container(
            height: 38,
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.cardSurface
                  : AppColors.lightElevatedSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.border : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 16,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search patients, reports...',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 12.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Ctrl+K',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textMuted
                        : AppColors.lightTextMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Notification Bell Icon Button
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardSurface
                : AppColors.lightElevatedSurface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.border : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Notifications',
                icon: Icon(
                  Icons.notifications_none_rounded,
                  size: 19,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
                onPressed: () {
                  context.push('/audit-logs');
                },
              ),
              Positioned(
                top: 8,
                right: 9,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF97316),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Sync Status Dropdown
        _SyncStatusDropdown(status: syncStatus),
        if (user != null) ...[
          const SizedBox(width: 8),
          _buildProfileButton(context, user),
        ],
      ],
    );
  }
}

class _IndexedNavItem {
  final int index;
  final AppNavigationItem item;
  const _IndexedNavItem(this.index, this.item);
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
        ? (isDark
              ? AppColors.primaryEmerald.withValues(alpha: 0.14)
              : AppColors.primaryEmerald.withValues(alpha: 0.12))
        : Colors.transparent;

    final foreground = selected
        ? AppColors.primaryEmerald
        : (isDark ? const Color(0xFF8E929B) : AppColors.lightTextSecondary);

    final content = Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        hoverColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.lightElevatedSurface,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 10 : 0,
            vertical: 8,
          ),
          child: expanded
              ? Row(
                  children: [
                    if (selected)
                      Container(
                        width: 3.5,
                        height: 18,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryEmerald,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    else
                      const SizedBox(width: 11.5),
                    Icon(
                      selected ? item.selectedIcon : item.icon,
                      size: 19,
                      color: foreground,
                    ),
                    const SizedBox(width: 10),
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
                    if (item.badgeCount != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.badgeColor ?? AppColors.primaryEmerald,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${item.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                )
              : Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        selected ? item.selectedIcon : item.icon,
                        size: 20,
                        color: foreground,
                      ),
                      if (item.badgeCount != null)
                        Positioned(
                          top: -3,
                          right: -5,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  item.badgeColor ?? AppColors.primaryEmerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
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
