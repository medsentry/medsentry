import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/user.dart';
import '../services/app_notification.dart';
import '../providers/providers.dart';
import '../utils/date_time_format.dart';
import 'layout/responsive_layout.dart';

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

/// Main app scaffold with navigation rail for desktop layout
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
  final _searchFocusNode = FocusNode();
  final _searchController = TextEditingController();
  bool _sidebarExpanded = true;

  static const _sidebarExpandedWidth = 228.0;
  static const _sidebarCollapsedWidth = 72.0;

  @override
  void initState() {
    super.initState();
    // Register keyboard shortcut for search (Ctrl+K)
    ServicesBinding.instance.keyboard.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    ServicesBinding.instance.keyboard.removeHandler(_handleKeyEvent);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Ctrl+K or Ctrl+F to focus search
      if ((event.logicalKey == LogicalKeyboardKey.keyK ||
              event.logicalKey == LogicalKeyboardKey.keyF) &&
          HardwareKeyboard.instance.isControlPressed) {
        if (ref.read(currentUserProvider)?.canAccessPatientRecords != true) {
          return false;
        }
        _searchFocusNode.requestFocus();
        return true;
      }
    }
    return false;
  }

  void _onSearch(String query) {
    final trimmed = query.trim();
    final user = ref.read(currentUserProvider);
    if (trimmed.isNotEmpty && user?.canAccessPatientRecords == true) {
      final encoded = Uri.encodeQueryComponent(trimmed);
      context.push('/patients?search=$encoded');
      _searchController.clear();
      _searchFocusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final isMobile = ResponsiveLayout.isMobile(context);
    final isTablet = ResponsiveLayout.isTablet(context);

    if (isMobile) {
      return Scaffold(
        appBar: _buildMobileAppBar(context, user, syncStatus),
        drawer: _buildDrawer(context, user, syncStatus),
        bottomNavigationBar: _buildMobileBottomNav(context),
        body: SafeArea(child: widget.body),
        floatingActionButton: widget.floatingActionButton,
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).appBarTheme.backgroundColor ??
                Theme.of(context).primaryColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 800;
                  final spacing = isCompact ? 12.0 : 24.0;

                  return Row(
                    children: [
                      // LEFT ZONE: Identity & Context
                      Flexible(
                        flex: isCompact ? 1 : 0,
                        child: _buildIdentityZone(context),
                      ),
                      SizedBox(width: spacing),
                      // CENTER ZONE: Global Action (Search)
                      Expanded(
                        flex: 3,
                        child: _buildSearchZone(
                          context,
                          enabled: user?.canAccessPatientRecords == true,
                        ),
                      ),
                      SizedBox(width: spacing),
                      // RIGHT ZONE: Status & User Profile (flexible to avoid overflow)
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
          // On tablet, lock sidebar to collapsed rail (72px) with tooltips
          _buildSidebar(context, forceCollapsed: isTablet),
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
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
    return AppBar(
      backgroundColor:
          Theme.of(context).appBarTheme.backgroundColor ??
          Theme.of(context).primaryColor,
      leading: Builder(
        builder: (drawerContext) => IconButton(
          tooltip: 'Open menu',
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(drawerContext).openDrawer(),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.local_hospital,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'MedSentry',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        if (user?.canAccessPatientRecords == true)
          IconButton(
            tooltip: 'Search Patients',
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => _showMobileSearchDialog(context),
          ),
        _SyncStatusDropdown(status: syncStatus),
        const SizedBox(width: 4),
        if (user != null) _buildMobileUserAvatar(context, user),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMobileUserAvatar(BuildContext context, User user) {
    return PopupMenuButton<String>(
      tooltip: 'Account Menu',
      offset: const Offset(0, 48),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white.withValues(alpha: 0.25),
        child: Text(
          user.initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
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
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                user.roleDisplay,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline),
              SizedBox(width: 8),
              Text('My Profile'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Log Out', style: TextStyle(color: Colors.red)),
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
            AppNotification.error(
              title: 'Logout Failed',
              message: '$e',
            );
          }
        }
      },
    );
  }

  Widget? _buildMobileBottomNav(BuildContext context) {
    // Only display on mobile if there are enough core items
    if (widget.navigationItems.length < 3) return null;

    final primaryItems = widget.navigationItems.take(4).toList();
    final currentIndex = widget.currentIndex;
    final selectedIndex = currentIndex < 4 ? currentIndex : 4;

    return NavigationBar(
      selectedIndex: selectedIndex,
      height: 64,
      onDestinationSelected: (index) {
        if (index == 4) {
          // Open drawer for extra destinations
          Scaffold.of(context).openDrawer();
          return;
        }
        _onNavigationSelected(index, context);
      },
      destinations: [
        ...primaryItems.map(
          (item) => NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          ),
        ),
        const NavigationDestination(
          icon: Icon(Icons.menu),
          selectedIcon: Icon(Icons.menu_open),
          label: 'More',
        ),
      ],
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    User? user,
    SyncStatus syncStatus,
  ) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: primary,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_hospital,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MedSentry',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              user?.isSuperAdmin == true
                                  ? 'Super Admin Network'
                                  : 'Rural Health Unit',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
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
                    expanded: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      _onNavigationSelected(index, context);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('My Profile'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log Out', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  await ref.read(authRepositoryProvider).logout();
                  ref.read(currentUserProvider.notifier).state = null;
                  if (context.mounted) {
                    context.go('/login');
                  }
                } catch (e) {
                  AppNotification.error(
                    title: 'Logout Failed',
                    message: '$e',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Search Patients'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter patient name or ID...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _searchController.clear(),
            ),
          ),
          onSubmitted: (query) {
            Navigator.of(dialogCtx).pop();
            _onSearch(query);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _onSearch(_searchController.text);
            },
            child: const Text('Search'),
          ),
        ],
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
    final isExpanded = !forceCollapsed && _sidebarExpanded;
    final width = isExpanded
        ? _sidebarExpandedWidth
        : _sidebarCollapsedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: width,
      color: theme.colorScheme.surface,
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
            const Divider(height: 1),
            _buildSidebarToggle(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarToggle(BuildContext context) {
    final label = _sidebarExpanded ? 'Collapse sidebar' : 'Expand sidebar';

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: _sidebarExpanded
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: [
              if (_sidebarExpanded)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'Collapse',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              IconButton(
                tooltip: label,
                onPressed: () =>
                    setState(() => _sidebarExpanded = !_sidebarExpanded),
                icon: AnimatedRotation(
                  turns: _sidebarExpanded ? 0 : 0.5,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.chevron_left),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// LEFT ZONE: Identity & Context
  Widget _buildIdentityZone(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.local_hospital,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        // App Name & Facility
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MedSentry',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ref.watch(currentUserProvider)?.isSuperAdmin == true
                    ? 'Super Admin • All RHUs'
                    : 'Healthcare Management Network',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight:
                      ref.watch(currentUserProvider)?.isSuperAdmin == true
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// CENTER ZONE: Global Action (Search)
  Widget _buildSearchZone(BuildContext context, {required bool enabled}) {
    return Container(
      height: 40,
      constraints: const BoxConstraints(maxWidth: 600),
      child: TextField(
        enabled: enabled,
        controller: _searchController,
        focusNode: _searchFocusNode,
        onSubmitted: _onSearch,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search patients by name, ID, or phone...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                  color: Colors.white70,
                ),
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Ctrl+K',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
      ),
    );
  }

  /// RIGHT ZONE: Status & User Profile
  Widget _buildStatusZone(
    BuildContext context,
    User? user,
    SyncStatus syncStatus,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 300;
        final hideClock = constraints.maxWidth < 200;

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
                        icon: const Icon(
                          Icons.install_desktop_outlined,
                          color: Colors.white,
                          size: 20,
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
              SizedBox(width: isCompact ? 12 : 16),
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
                        _formatTime(now),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!isCompact)
                        Text(
                          _formatDate(now),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],

            SizedBox(width: isCompact ? 12 : 16),

            // User Profile
            if (user != null)
              PopupMenuButton<String>(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).primaryColor,
                      radius: 18,
                      child: Text(
                        user.initials.isNotEmpty ? user.initials : 'U',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (!isCompact) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              user.roleDisplay,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                itemBuilder: (context) => [
                  if (ref.watch(pwaInstallerProvider).canInstall)
                    const PopupMenuItem(
                      value: 'install_pwa',
                      child: Row(
                        children: [
                          Icon(
                            Icons.install_desktop_outlined,
                            color: Color(0xFF0D9488),
                          ),
                          SizedBox(width: 8),
                          Text('Install App to Device'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'lock',
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        const Text('Lock Screen'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline),
                        SizedBox(width: 8),
                        Text('My Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Log Out',
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  switch (value) {
                    case 'install_pwa':
                      final installer = ref.read(pwaInstallerProvider);
                      final installed = await installer.promptInstall();
                      if (installed) {
                        AppNotification.success(
                          title: 'Installation Started',
                          message:
                              'MedSentry is being installed to your device.',
                        );
                      }
                      break;
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

  String _formatTime(DateTime dateTime) {
    return formatTime12h(dateTime);
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final background = selected
        ? primary.withValues(alpha: 0.12)
        : Colors.transparent;
    final foreground = selected ? primary : theme.colorScheme.onSurface;

    final content = Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
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
                        size: 22,
                        color: foreground,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: foreground,
                          ),
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Icon(
                      selected ? item.selectedIcon : item.icon,
                      size: 22,
                      color: foreground,
                    ),
                  ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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
        color = Colors.green;
        statusText = 'Online & Synced';
        icon = Icons.cloud_done;
        break;
      case SyncStatus.syncing:
        color = Colors.blue;
        statusText = 'Syncing...';
        icon = Icons.sync;
        break;
      case SyncStatus.pending:
        color = Colors.orange;
        statusText = 'Offline (Pending)';
        icon = Icons.cloud_off;
        break;
      case SyncStatus.error:
        color = Colors.red;
        statusText = 'Sync Error';
        icon = Icons.error_outline;
        break;
      case SyncStatus.offline:
        color = Colors.grey;
        statusText = 'Offline Mode';
        icon = Icons.cloud_off;
        break;
    }

    return PopupMenuButton<String>(
      tooltip: 'Sync Status: $statusText',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'sync_now',
          child: Row(
            children: [Icon(Icons.sync), SizedBox(width: 8), Text('Sync Now')],
          ),
        ),
        const PopupMenuItem(
          value: 'sync_settings',
          child: Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text('Sync Settings'),
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
