import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/patient.dart';
import '../providers/providers.dart';

/// Modern, responsive, keyboard-first Command Palette (Ctrl+K / Search Bar) for MedSentry RHU.
/// Enables rapid clinical navigation, patient lookups, and operational shortcuts.
Future<void> showMedsentryCommandPalette(
  BuildContext context,
  WidgetRef ref,
) async {
  final isMobile = MediaQuery.of(context).size.width < 640;
  await showDialog<void>(
    context: context,
    useSafeArea: !isMobile,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (dialogCtx) => const MedSentryCommandPaletteDialog(),
  );
}

class MedSentryCommandPaletteDialog extends ConsumerStatefulWidget {
  const MedSentryCommandPaletteDialog({super.key});

  @override
  ConsumerState<MedSentryCommandPaletteDialog> createState() =>
      _MedSentryCommandPaletteDialogState();
}

class _MedSentryCommandPaletteDialogState
    extends ConsumerState<MedSentryCommandPaletteDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 640;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final safePadding = MediaQuery.of(context).padding;
    final dialogWidth = isMobile
        ? screenWidth
        : (screenWidth > 640 ? 600.0 : screenWidth - 28);

    final user = ref.watch(currentUserProvider);
    final settings = ref.watch(systemSettingsProvider).valueOrNull;

    // 1. Matched Patients
    List<Patient> matchedPatients = [];
    if (_query.isNotEmpty && user?.canAccessPatientRecords == true) {
      final patients = ref.watch(patientsProvider).valueOrNull ?? <Patient>[];
      matchedPatients = patients
          .where((p) {
            final nameMatch = p.fullName.toLowerCase().contains(_query);
            final idMatch = p.id.toLowerCase().contains(_query);
            final brgyMatch = (p.barangay ?? '').toLowerCase().contains(_query);
            final contactMatch = (p.contactNumber ?? '').contains(_query);
            return nameMatch || idMatch || brgyMatch || contactMatch;
          })
          .take(6)
          .toList();
    }

    // 2. Navigation items
    final navPages = [
      (
        label: 'Dashboard Overview',
        path: '/dashboard',
        icon: Icons.dashboard_outlined,
        allowed: true,
      ),
      (
        label: 'RHU Facilities Management',
        path: '/rhus',
        icon: Icons.domain_outlined,
        allowed: user?.isSuperAdmin == true,
      ),
      (
        label: 'Patients Directory',
        path: '/patients',
        icon: Icons.people_outline,
        allowed: user?.canAccessPatientRecords == true,
      ),
      (
        label: 'Clinical Documents & Records',
        path: '/documents',
        icon: Icons.folder_outlined,
        allowed: user?.canManageDocuments == true,
      ),
      (
        label: 'Medical Certificates Issuance',
        path: '/certificates',
        icon: Icons.description_outlined,
        allowed:
            user?.canGenerateCertificates == true &&
            (settings?.certificatesModuleEnabled ?? true),
      ),
      (
        label: 'Reports & Analytics',
        path: '/reports',
        icon: Icons.assessment_outlined,
        allowed: user?.canGenerateReports == true,
      ),
      (
        label: 'Archived Patient Records',
        path: '/archive',
        icon: Icons.inventory_2_outlined,
        allowed: user?.canManageArchive == true,
      ),
      (
        label: 'Staff Accounts & Roles',
        path: '/staff',
        icon: Icons.manage_accounts_outlined,
        allowed: user?.canManageStaffAccounts == true,
      ),
      (
        label: 'Cloud & LAN Sync',
        path: '/sync',
        icon: Icons.cloud_sync_outlined,
        allowed:
            user?.canSyncRecords == true &&
            (settings?.syncModuleEnabled ?? true),
      ),
      (
        label: 'Audit Logs & Compliance',
        path: '/audit-logs',
        icon: Icons.history_outlined,
        allowed: user?.canViewAuditLogs == true,
      ),
      (
        label: 'Settings & System Configuration',
        path: '/settings',
        icon: Icons.settings_outlined,
        allowed: user?.canAccessSettings == true,
      ),
      (
        label: 'My User Profile',
        path: '/profile',
        icon: Icons.account_circle_outlined,
        allowed: true,
      ),
    ];

    final filteredNav = navPages.where((p) {
      if (!p.allowed) return false;
      if (_query.isEmpty) return true;
      return p.label.toLowerCase().contains(_query) ||
          p.path.toLowerCase().contains(_query);
    }).toList();

    // 3. Quick Actions
    final actions = [
      if (user?.canRegisterPatients == true)
        (
          title: 'Register New Patient',
          subtitle: 'Open enrollment & clinical intake modal',
          icon: Icons.person_add_outlined,
          execute: () {
            Navigator.of(context).pop();
            context.go('/patients?action=add-patient');
          },
        ),
      (
        title: 'Switch Color Mode (Dark / Light)',
        subtitle: 'Toggle obsidian clinical dark or high-contrast light mode',
        icon: Icons.brightness_6_outlined,
        execute: () {
          Navigator.of(context).pop();
          final currentMode = ref.read(themeModeProvider);
          ref
              .read(themeModeProvider.notifier)
              .setThemeMode(
                currentMode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              );
        },
      ),
      (
        title: 'Lock Screen / Session',
        subtitle: (user?.pinEnabled == true)
            ? 'Lock terminal; unlock instantly with your 4-digit PIN'
            : 'Lock the current workstation session',
        icon: Icons.lock_outline,
        execute: () async {
          final navigator = Navigator.of(context);
          final router = GoRouter.of(context);
          final authRepo = ref.read(authRepositoryProvider);
          final userNotifier = ref.read(currentUserProvider.notifier);
          navigator.pop();
          await authRepo.lockSession(userId: user?.id);
          userNotifier.state = null;
          router.go('/login?locked=1');
        },
      ),
      if (user?.canSyncRecords == true)
        (
          title: 'Trigger Force Sync Cycle',
          subtitle: 'Synchronize local records with cloud database',
          icon: Icons.sync_outlined,
          execute: () {
            Navigator.of(context).pop();
            ref.read(syncServiceProvider).startSync();
          },
        ),
    ];

    final filteredActions = actions.where((a) {
      if (_query.isEmpty) return true;
      return a.title.toLowerCase().contains(_query) ||
          a.subtitle.toLowerCase().contains(_query);
    }).toList();

    final hasAnyResults =
        matchedPatients.isNotEmpty ||
        filteredNav.isNotEmpty ||
        filteredActions.isNotEmpty;

    final bgColor = isDark ? AppColors.modalSurface : Colors.white;
    final borderColor = isDark ? AppColors.border : const Color(0xFFE5E7EB);
    final headerBg = isDark ? AppColors.elevatedSurface : AppColors.lightCardSurface;

    return Dialog(
      backgroundColor: isMobile ? bgColor : Colors.transparent,
      elevation: 0,
      insetPadding: isMobile
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: Center(
        child: Container(
          width: dialogWidth,
          height: isMobile ? screenHeight : null,
          constraints: BoxConstraints(
            maxHeight: isMobile ? screenHeight : screenHeight * 0.78,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: isMobile
                ? BorderRadius.zero
                : BorderRadius.circular(16),
            border: isMobile
                ? null
                : Border.all(color: borderColor, width: 1.2),
            boxShadow: isMobile
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.6 : 0.25,
                      ),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: isMobile
                ? BorderRadius.zero
                : BorderRadius.circular(15),
            child: Column(
              mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
              children: [
                // Top Search Bar Header
                Container(
                  color: headerBg,
                  padding: EdgeInsets.only(
                    top: isMobile ? safePadding.top + 8 : 10,
                    bottom: 10,
                    left: isMobile ? 8 : 14,
                    right: 14,
                  ),
                  child: Row(
                    children: [
                      if (isMobile)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: isDark ? Colors.white70 : Colors.black87,
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Back',
                        )
                      else ...[
                        Icon(
                          Icons.search_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search patients, navigation, actions...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textMuted
                                  : Colors.grey.shade500,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          onSubmitted: (_) {
                            // If enter is pressed and we have a top match, trigger it
                            if (matchedPatients.isNotEmpty) {
                              Navigator.of(context).pop();
                              context.push(
                                '/patients/${matchedPatients.first.id}',
                              );
                            } else if (filteredNav.isNotEmpty) {
                              Navigator.of(context).pop();
                              context.go(filteredNav.first.path);
                            } else if (filteredActions.isNotEmpty) {
                              filteredActions.first.execute();
                            }
                          },
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Clear',
                          onPressed: () {
                            _searchController.clear();
                          },
                        ),
                      if (!isMobile) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            'ESC',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? AppColors.border : const Color(0xFFE5E7EB),
                ),

                // Results Body
                Flexible(
                  child: !hasAnyResults
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 36,
                            horizontal: 24,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 36,
                                color: isDark
                                    ? AppColors.textMuted
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No results found',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textPrimary
                                      : Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No patients, navigation links, or actions match "$_query"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          shrinkWrap: !isMobile,
                          padding: EdgeInsets.fromLTRB(
                            6,
                            8,
                            6,
                            isMobile ? (viewInsets.bottom + 24) : 8,
                          ),
                          children: [
                            // Section: Patients
                            if (matchedPatients.isNotEmpty) ...[
                              _buildSectionHeader('PATIENTS', isDark),
                              ...matchedPatients.map((patient) {
                                final genderChar =
                                    (patient.gender != null &&
                                        patient.gender!.isNotEmpty)
                                    ? patient.gender![0].toUpperCase()
                                    : 'U';
                                final ageLabel = patient.age != null
                                    ? '${patient.age}y'
                                    : '';
                                final subtitle = [
                                  genderChar,
                                  ageLabel,
                                ].where((s) => s.isNotEmpty).join(', ');

                                return _buildPaletteItem(
                                  icon: Icons.person_outline_rounded,
                                  iconColor: AppColors.primaryEmerald,
                                  title: '${patient.fullName} ($subtitle)',
                                  subtitle: patient.barangay ?? 'No Barangay',
                                  trailingBadge: patient.id,
                                  isDark: isDark,
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    context.push('/patients/${patient.id}');
                                  },
                                );
                              }),
                            ],

                            // Section: Navigation
                            if (filteredNav.isNotEmpty) ...[
                              _buildSectionHeader('NAVIGATION', isDark),
                              ...filteredNav.map((page) {
                                return _buildPaletteItem(
                                  icon: page.icon,
                                  iconColor: isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700,
                                  title: page.label,
                                  trailingBadge: page.path,
                                  isDark: isDark,
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    context.go(page.path);
                                  },
                                );
                              }),
                            ],

                            // Section: Actions
                            if (filteredActions.isNotEmpty) ...[
                              _buildSectionHeader('ACTIONS', isDark),
                              ...filteredActions.map((action) {
                                return _buildPaletteItem(
                                  icon: action.icon,
                                  iconColor: isDark
                                      ? Colors.amber.shade300
                                      : Colors.amber.shade700,
                                  title: action.title,
                                  subtitle: action.subtitle,
                                  isDark: isDark,
                                  onTap: action.execute,
                                );
                              }),
                            ],
                          ],
                        ),
                ),

                // Bottom Hint Footer (desktop/tablet only)
                if (!isMobile)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.inputSurface
                          : const Color(0xFFF3F4F6),
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? AppColors.border
                              : const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MedSentry RHU Command Palette',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textMuted
                                : Colors.grey.shade600,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Tap or press Enter to navigate',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.textMuted
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? AppColors.textMuted : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildPaletteItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    String? trailingBadge,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textPrimary
                            : Colors.grey.shade900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondary
                              : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingBadge != null && trailingBadge.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    trailingBadge,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: isDark
                          ? AppColors.textSecondary
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
