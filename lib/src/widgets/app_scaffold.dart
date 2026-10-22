import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/audit_log.dart';
import '../models/system_settings.dart';
import '../models/system_notification.dart';
import '../models/user.dart';
import '../services/app_notification.dart';
import '../providers/providers.dart';
import '../utils/context_extensions.dart';
import '../utils/date_time_format.dart';
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
    final isMobile = ResponsiveLayout.isMobile(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final theme = Theme.of(context);

    if (isMobile) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _buildMobileAppBar(context, user),
        drawer: _buildDrawer(context, user),
        body: SafeArea(top: false, child: widget.body),
        floatingActionButton: widget.floatingActionButton,
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          _buildSidebar(context, forceCollapsed: isTablet),
          if (theme.brightness == Brightness.dark)
            const VerticalDivider(
              thickness: AppColors.borderWidth,
              width: AppColors.borderWidth,
              color: AppColors.borderSubtle,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDesktopHeader(context, user),
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  Widget _buildDesktopHeader(BuildContext context, User? user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 76.0,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.sidebarBackground
            : AppColors.lightCardSurface,
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
            _buildHeaderActionsZone(context, user),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context, User? user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentPath = GoRouter.maybeOf(context)?.state.uri.path ?? '';
    final isDetailRoute =
        currentPath.startsWith('/patients/') && currentPath != '/patients';

    final notificationTarget = user?.canManageSystemData == true
        ? NotificationTarget.admin
        : NotificationTarget.staff;
    final unreadCount =
        (ref
                .watch(notificationsProvider(notificationTarget))
                .valueOrNull
                ?.where((notification) => !notification.isRead)
                .length ??
            0) +
        (user == null ? 0 : ref.watch(activityUnreadCountProvider(user.id)));

    // Phones keep the bar to the screen title and the actions used most;
    // the theme switch stays in Settings, Appearance.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showThemeToggle = screenWidth >= 430;

    return AppBar(
      elevation: 0,
      backgroundColor: isDark
          ? AppColors.sidebarBackground
          : AppColors.lightCardSurface,
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
      // The logo is in the drawer; here the screen title gets the room.
      title: Text(
        widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Search (Ctrl+K)',
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(6),
          icon: Icon(
            Icons.search,
            size: 20,
            color: isDark
                ? AppColors.textSecondary
                : AppColors.lightTextSecondary,
          ),
          onPressed: () => showMedsentryCommandPalette(context, ref),
        ),
        if (showThemeToggle)
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
              color: isDark
                  ? const Color(0xFFFBBF24)
                  : AppColors.lightTextSecondary,
            ),
            onPressed: () {
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
            },
          ),
        if (user != null)
          IconButton(
            tooltip: 'Notifications',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
              child: Icon(
                unreadCount > 0
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_rounded,
                size: 20,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            onPressed: () => _showNotifications(context, notificationTarget),
          ),
        const SizedBox(width: 4),
        const _SyncStatusDropdown(),
        if (user != null) ...[
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 4),
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
    return PopupMenuButton<String>(
      tooltip: 'Account & Security (${user.displayName})',
      offset: const Offset(0, 42),
      onSelected: (val) async {
        if (val == 'profile') {
          context.push('/profile');
        } else if (val == 'lock') {
          await _lockSession(context);
        } else if (val == 'settings') {
          context.push('/settings');
        } else if (val == 'logout') {
          await _logout(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? AppColors.textPrimary : Colors.black87,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                user.email,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondary
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  user.roleDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.account_circle_outlined, size: 20),
            title: Text('My Profile', style: TextStyle(fontSize: 14)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        PopupMenuItem<String>(
          value: 'lock',
          child: ListTile(
            leading: Icon(
              Icons.lock_outline,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text(
              'Lock Screen',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              user.pinEnabled
                  ? 'Unlock with your 4-digit PIN'
                  : 'Lock current device session',
              style: const TextStyle(fontSize: 12),
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        if (user.canAccessSettings)
          const PopupMenuItem<String>(
            value: 'settings',
            child: ListTile(
              leading: Icon(Icons.settings_outlined, size: 20),
              title: Text('Settings', style: TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            leading: Icon(
              Icons.logout,
              size: 20,
              color: context.semanticColors.critical,
            ),
            title: Text(
              'Log Out',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.semanticColors.critical,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, User? user) {
    final spine = AppSpine.of(context);
    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();

    return Drawer(
      backgroundColor: spine.background,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: spine.raised,
                border: Border(bottom: BorderSide(color: spine.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SystemLogo(
                        dataUri: settings.logoDataUri,
                        size: 40,
                        backgroundColor: spine.tab,
                        iconColor: spine.tabText,
                        iconSize: 24,
                        borderRadius: AppRadius.lg,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settings.appName,
                              style: TextStyle(
                                color: spine.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              user?.isSuperAdmin == true
                                  ? 'Super Admin Network'
                                  : 'Rural Health Unit',
                              style: TextStyle(
                                color: spine.textSecondary,
                                fontSize: 13,
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
                      color: spine.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(color: spine.textSecondary, fontSize: 14),
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
    final spine = AppSpine.of(context);
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
      color: spine.background,
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
                        _groupLabel(entry.key),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: spine.textMuted,
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

          if (!forceCollapsed) ...[
            Divider(height: 1, color: spine.border),
            _buildSidebarToggle(context),
          ],
        ],
      ),
    );
  }

  /// Group keys are stored in capitals; the spine shows them in sentence case.
  String _groupLabel(String key) => key.isEmpty
      ? key
      : '${key[0].toUpperCase()}${key.substring(1).toLowerCase()}';

  Widget _buildSidebarBrand(
    BuildContext context,
    bool isExpanded,
    SystemSettings settings,
  ) {
    final spine = AppSpine.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isExpanded ? 16 : 12,
        vertical: 18,
      ),
      child: Align(
        alignment: isExpanded ? Alignment.centerLeft : Alignment.center,
        child: Tooltip(
          message: '${settings.appName} Clinical System',
          child: InkWell(
            borderRadius: AppRadius.roundedLg,
            onTap: () {
              final user = ref.read(currentUserProvider);
              context.go(user?.homePath ?? '/dashboard');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: spine.tileBorder == null ? spine.tab : spine.raised,
                    borderRadius: AppRadius.roundedLg,
                    border: spine.tileBorder == null
                        ? null
                        : Border.all(color: spine.tileBorder!, width: 1.2),
                  ),
                  child: Center(
                    child: SystemLogo(
                      dataUri: settings.logoDataUri,
                      size: 26,
                      backgroundColor: Colors.transparent,
                      iconColor: spine.tabText,
                      iconSize: 22,
                      borderRadius: 4,
                    ),
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      settings.appName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: spine.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
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

  Future<void> _lockSession(BuildContext context) async {
    try {
      final user = ref.read(currentUserProvider);
      await ref.read(authRepositoryProvider).lockSession(userId: user?.id);
      ref.read(currentUserProvider.notifier).state = null;
      if (context.mounted) context.go('/login?locked=1');
    } catch (e) {
      AppNotification.error(title: 'Lock Failed', message: '$e');
    }
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
    final spine = AppSpine.of(context);
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: spine.textSecondary,
                  ),
                ),
              AnimatedRotation(
                turns: _sidebarExpanded ? 0 : 0.5,
                duration: AppDurations.normal,
                child: Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: spine.textSecondary,
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

  // An icon rather than an emoji: the web app downloads emoji fonts from
  // Google, so offline the emoji rendered as an empty box.
  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 18) return Icons.wb_sunny_outlined;
    return Icons.nightlight_outlined;
  }

  String _getUserGreetingName(User? user) {
    if (user == null) return 'User';
    if (user.displayName.isNotEmpty) return user.displayName;
    return user.email;
  }

  Widget _buildGreetingZone(BuildContext context, User? user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings =
        ref.watch(systemSettingsProvider).valueOrNull ?? const SystemSettings();
    final clinics = ref.watch(clinicsProvider).valueOrNull ?? const [];
    final assignedClinicName = user?.clinicId == null
        ? null
        : clinics
              .where((c) => c.id == user!.clinicId)
              .map((c) => c.name)
              .firstOrNull;

    final isDashboard = widget.title == 'Dashboard' || widget.title.isEmpty;
    final timeGreeting = _getTimeGreeting();
    final userName = _getUserGreetingName(user);
    final greetingTitle = isDashboard
        ? '$timeGreeting, $userName'
        : widget.title;

    final facility =
        (assignedClinicName != null && assignedClinicName.isNotEmpty)
        ? assignedClinicName
        : (settings.clinicName.isNotEmpty
              ? settings.clinicName
              : settings.appName);

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
            if (isDashboard) ...[
              const SizedBox(width: 6),
              Icon(
                _getGreetingIcon(),
                size: 18,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.lightTextPrimary,
              ),
            ],
            const SizedBox(width: 10),
            const _LiveClockPill(),
          ],
        ),
        const SizedBox(height: 3),
        _LiveHeaderClockSubtitle(facility: facility, isDark: isDark),
      ],
    );
  }

  Widget _buildHeaderActionsZone(BuildContext context, User? user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notificationTarget = user?.canManageSystemData == true
        ? NotificationTarget.admin
        : NotificationTarget.staff;
    final notificationsAsync = ref.watch(
      notificationsProvider(notificationTarget),
    );
    final unreadCount =
        (notificationsAsync.valueOrNull
                ?.where((notification) => !notification.isRead)
                .length ??
            0) +
        (user == null ? 0 : ref.watch(activityUnreadCountProvider(user.id)));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pill Search Bar (Ctrl+K)
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: user != null
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
                    'Search patients, modules...',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 14,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Theme Mode Toggle Button
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
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 19,
              color: isDark
                  ? const Color(0xFFFBBF24)
                  : AppColors.lightTextSecondary,
            ),
            onPressed: () {
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
            },
          ),
        ),
        const SizedBox(width: 10),

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
                  unreadCount > 0
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_rounded,
                  size: 19,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
                onPressed: user == null
                    ? null
                    : () => _showNotifications(context, notificationTarget),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 2,
                  right: 1,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? AppColors.sidebarBackground
                            : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Sync Status Dropdown
        const _SyncStatusDropdown(),
        if (user != null) ...[
          const SizedBox(width: 8),
          _buildProfileButton(context, user),
        ],
      ],
    );
  }

  Future<void> _showNotifications(
    BuildContext context,
    NotificationTarget target,
  ) async {
    final router = GoRouter.of(context);
    try {
      await ref.read(notificationServiceProvider).refreshSystemNotifications();
      ref.invalidate(notificationsProvider(target));
    } catch (e) {
      AppNotification.error(
        title: 'Notification Error',
        message: 'Could not refresh notifications: $e',
      );
      return;
    }
    if (!mounted || !context.mounted) return;

    // Opening the list counts as seeing the team's activity; keep the old
    // time so entries that were new stay highlighted while it is open.
    final userId = ref.read(currentUserProvider)?.id ?? '';
    final activitySeenBefore = ref.read(activitySeenProvider(userId));
    final hadNewActivity = ref.read(activityUnreadCountProvider(userId)) > 0;
    final hadUnreadAlerts =
        ref
            .read(notificationsProvider(target))
            .valueOrNull
            ?.any((notification) => !notification.isRead) ??
        false;
    unawaited(ref.read(activitySeenProvider(userId).notifier).markSeen());

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _NotificationsDialog(
        target: target,
        userId: userId,
        activitySeenBefore: activitySeenBefore,
        startOnAlerts: hadUnreadAlerts && !hadNewActivity,
        onOpenActivity: (log) {
          final route = _activityRoute(log);
          Navigator.pop(dialogContext);
          if (route != null) router.push(route);
        },
        onOpen: (notification) async {
          try {
            await ref
                .read(databaseProvider)
                .markNotificationRead(notification.id);
            ref.invalidate(notificationsProvider(target));
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (!mounted) return;
            if (notification.actionRoute != null &&
                notification.actionRoute!.startsWith('/')) {
              router.push(notification.actionRoute!);
            }
          } catch (e) {
            AppNotification.error(
              title: 'Notification Error',
              message: 'Could not open this notification: $e',
            );
          }
        },
        onMarkAllRead: () async {
          try {
            await ref.read(activitySeenProvider(userId).notifier).markSeen();
            await ref.read(databaseProvider).markAllNotificationsRead(target);
            ref.invalidate(notificationsProvider(target));
          } catch (e) {
            AppNotification.error(
              title: 'Notification Error',
              message: 'Could not mark notifications as read: $e',
            );
          }
        },
      ),
    );
  }

  /// Where tapping an activity entry leads, if anywhere still exists.
  String? _activityRoute(AuditLog log) {
    if (log.action == AuditAction.delete) return null;
    final patientId = log.patientId;
    if (patientId != null && patientId.isNotEmpty) {
      return '/patients/$patientId';
    }
    return switch (log.entityType) {
      AuditEntityTypes.document => '/documents',
      AuditEntityTypes.certificate => '/certificates',
      AuditEntityTypes.report => '/reports',
      AuditEntityTypes.user => '/staff',
      AuditEntityTypes.clinic => '/rhus',
      _ => null,
    };
  }
}

class _NotificationsDialog extends ConsumerWidget {
  final NotificationTarget target;
  final String userId;
  final DateTime? activitySeenBefore;
  final bool startOnAlerts;
  final ValueChanged<AuditLog> onOpenActivity;
  final ValueChanged<SystemNotification> onOpen;
  final Future<void> Function() onMarkAllRead;

  const _NotificationsDialog({
    required this.target,
    required this.userId,
    required this.activitySeenBefore,
    required this.startOnAlerts,
    required this.onOpenActivity,
    required this.onOpen,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unreadAlerts =
        ref
            .watch(notificationsProvider(target))
            .valueOrNull
            ?.where((notification) => !notification.isRead)
            .length ??
        0;
    final newActivity = countUnreadActivity(
      ref.watch(activityFeedProvider).valueOrNull ?? const [],
      seenAt: activitySeenBefore,
      userId: userId,
    );

    Tab tab(String label, int count) => Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Badge(label: Text(count > 99 ? '99+' : '$count')),
          ],
        ],
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
        child: DefaultTabController(
          length: 2,
          initialIndex: startOnAlerts ? 1 : 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => onMarkAllRead(),
                      child: const Text('Mark all read'),
                    ),
                    IconButton(
                      tooltip: 'Close notifications',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              TabBar(
                tabs: [
                  tab('Activity', newActivity),
                  tab('Alerts', unreadAlerts),
                ],
              ),
              Flexible(
                child: TabBarView(
                  children: [
                    _ActivityList(
                      userId: userId,
                      seenBefore: activitySeenBefore,
                      onOpen: onOpenActivity,
                    ),
                    _buildAlerts(context, ref),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlerts(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notificationsAsync = ref.watch(notificationsProvider(target));

    return notificationsAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load notifications: $error'),
                  ),
                ),
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 36,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.45,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('You’re all caught up'),
                            const SizedBox(height: 4),
                            Text(
                              'New alerts will appear here.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 68, endIndent: 16),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return ListTile(
                        onTap: () => onOpen(notification),
                        leading: CircleAvatar(
                          backgroundColor: notification.isRead
                              ? (isDark
                                    ? AppColors.elevatedSurface
                                    : AppColors.lightElevatedSurface)
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                          child: Icon(
                            _notificationIcon(notification.type),
                            color: notification.isRead
                                ? theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  )
                                : theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: notification.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'MMM d, h:mm a',
                                ).format(notification.createdAt),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        isThreeLine: true,
                      );
                    },
                  );
                },
              );
  }

  IconData _notificationIcon(NotificationType type) => switch (type) {
    NotificationType.incompleteRecord => Icons.person_search_outlined,
    NotificationType.syncFailed => Icons.cloud_sync_outlined,
    NotificationType.pendingDocument => Icons.upload_file_outlined,
    NotificationType.suspiciousActivity => Icons.security_outlined,
    NotificationType.systemUpdate => Icons.system_update_outlined,
    NotificationType.queueAlert => Icons.pending_actions_outlined,
    NotificationType.general => Icons.notifications_outlined,
  };
}

/// Team actions from the audit log, newest first.
class _ActivityList extends ConsumerWidget {
  final String userId;
  final DateTime? seenBefore;
  final ValueChanged<AuditLog> onOpen;

  const _ActivityList({
    required this.userId,
    required this.seenBefore,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final feedAsync = ref.watch(activityFeedProvider);

    return feedAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load activity: $error'),
        ),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_toggle_off_outlined,
                    size: 36,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 12),
                  const Text('No activity yet'),
                  const SizedBox(height: 4),
                  Text(
                    'Actions by your team will appear here.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: logs.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, indent: 68, endIndent: 16),
          itemBuilder: (context, index) {
            final log = logs[index];
            final isMine = log.userId == userId;
            final isNew =
                !isMine &&
                seenBefore != null &&
                log.timestamp.isAfter(seenBefore!);
            final (icon, color) = _actionStyle(log.action);
            final actor = isMine
                ? 'You'
                : [
                    log.userName ?? 'Someone',
                    if (log.userRole != null) '(${log.userRole})',
                  ].join(' ');

            return ListTile(
              onTap: () => onOpen(log),
              tileColor: isNew
                  ? theme.colorScheme.primary.withValues(alpha: 0.06)
                  : null,
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: isDark ? 0.18 : 0.12),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      _activityTitle(log),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isNew ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isNew)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$actor · ${formatRelativeTime(log.timestamp)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// The recorded description, or a plain summary when there is none
  /// (entries synced before descriptions were shared).
  static String _activityTitle(AuditLog log) {
    final description = log.description?.trim();
    if (description != null && description.isNotEmpty) return description;
    final subject = log.patientName ?? switch (log.entityType) {
      AuditEntityTypes.patient => 'a patient record',
      AuditEntityTypes.document => 'a document',
      AuditEntityTypes.certificate => 'a certificate',
      AuditEntityTypes.report => 'a report',
      AuditEntityTypes.user => 'a user account',
      AuditEntityTypes.clinic => 'an RHU',
      AuditEntityTypes.settings => 'system settings',
      _ => log.entityType.replaceAll('_', ' '),
    };
    return switch (log.action) {
      AuditAction.login => 'Signed in',
      AuditAction.logout => 'Signed out',
      AuditAction.backup => 'Backed up data',
      AuditAction.restore => 'Restored data',
      AuditAction.settingsChange => 'Changed system settings',
      AuditAction.passwordChange => 'Changed a password',
      AuditAction.pinChange => 'Changed a PIN',
      _ => '${log.action.displayName} $subject',
    };
  }

  static (IconData, Color) _actionStyle(AuditAction action) =>
      switch (action) {
        AuditAction.create => (Icons.add_circle_outline, AppColors.success),
        AuditAction.update => (Icons.edit_outlined, AppColors.info),
        AuditAction.delete => (Icons.delete_outline, AppColors.critical),
        AuditAction.login => (Icons.login, AppColors.primaryEmerald),
        AuditAction.logout => (Icons.logout, AppColors.textMuted),
        AuditAction.export => (Icons.file_download_outlined, AppColors.info),
        AuditAction.print => (Icons.print_outlined, AppColors.info),
        AuditAction.backup ||
        AuditAction.restore => (Icons.backup_outlined, AppColors.warning),
        AuditAction.settingsChange => (Icons.tune, AppColors.warning),
        AuditAction.passwordChange ||
        AuditAction.pinChange => (Icons.key_outlined, AppColors.warning),
        AuditAction.roleChange => (
          Icons.admin_panel_settings_outlined,
          AppColors.warning,
        ),
        _ => (Icons.history, AppColors.textMuted),
      };
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
    final spine = AppSpine.of(context);
    final background = selected ? spine.tab : Colors.transparent;
    final foreground = selected ? spine.tabText : spine.textSecondary;

    final content = Material(
      color: background,
      borderRadius: AppRadius.roundedSm,
      child: InkWell(
        borderRadius: AppRadius.roundedSm,
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        hoverColor: selected ? Colors.transparent : spine.hover,
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
                          color: spine.mark,
                          borderRadius: BorderRadius.circular(1),
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
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w700
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
                          color: item.badgeColor ?? spine.mark,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${item.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFeatures: AppType.tabular,
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
                              color: item.badgeColor ?? spine.mark,
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
  const _SyncStatusDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
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
                  fontSize: 14,
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
              Text('Sync Now', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'sync_settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18),
              SizedBox(width: 8),
              Text('Sync Settings', style: TextStyle(fontSize: 14)),
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
            context.go('/sync');
            break;
        }
      },
    );
  }
}

class _LiveClockPill extends StatefulWidget {
  const _LiveClockPill();

  @override
  State<_LiveClockPill> createState() => _LiveClockPillState();
}

class _LiveClockPillState extends State<_LiveClockPill> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(_now);
    return Container(
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
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$timeStr PHT • Live',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveHeaderClockSubtitle extends StatefulWidget {
  final String facility;
  final bool isDark;

  const _LiveHeaderClockSubtitle({
    required this.facility,
    required this.isDark,
  });

  @override
  State<_LiveHeaderClockSubtitle> createState() =>
      _LiveHeaderClockSubtitleState();
}

class _LiveHeaderClockSubtitleState extends State<_LiveHeaderClockSubtitle> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(_now);
    final dateStr = DateFormat('EEEE, d MMMM y').format(_now);
    final subtitle = '$timeStr PHT · $dateStr · ${widget.facility}';

    return Text(
      subtitle,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      style: TextStyle(
        fontSize: 13,
        color: widget.isDark
            ? AppColors.textSecondary
            : AppColors.lightTextSecondary,
      ),
    );
  }
}
