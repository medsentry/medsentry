import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/audit_log.dart';
import '../models/clinic.dart';
import '../models/user.dart';
import '../services/app_notification.dart';
import '../services/document_service.dart';
import '../providers/providers.dart';
import '../widgets/app_card.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/change_pin_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';
import '../widgets/screen_kit.dart';
import '../widgets/system_logo.dart';
import '../widgets/status_badge.dart';
import '../widgets/user_avatar.dart';
import '../utils/context_extensions.dart';
import '../utils/date_time_format.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsDataProvider);
    final currentUser = ref.watch(currentUserProvider);

    return ResponsiveContentContainer(
      padding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          ScreenHeader(
            icon: Icons.tune_outlined,
            title: currentUser?.isSuperAdmin == true
                ? 'Platform Settings & System Configuration'
                : 'Clinic Settings & Facility Administration',
            subtitle: currentUser?.isSuperAdmin == true
                ? 'Manage master platform branding, security policies, and system-wide infrastructure.'
                : 'Manage your local health facility, operational services, and clinic preferences.',
          ),
          const SizedBox(height: 16),
          _buildAppearanceSection(context, ref),
          const SizedBox(height: 16),
          _buildSection(context, 'Security', [
            _buildListTile(
              context,
              (currentUser?.pinEnabled == true &&
                      currentUser?.pinHash != null &&
                      currentUser!.pinHash!.isNotEmpty)
                  ? 'Change PIN'
                  : 'Setup PIN',
              (currentUser?.pinEnabled == true &&
                      currentUser?.pinHash != null &&
                      currentUser!.pinHash!.isNotEmpty)
                  ? 'Update your 4-digit access PIN'
                  : 'Setup a 4-digit access PIN for quick login',
              Icons.pin,
              () => showChangePinDialog(context, ref),
            ),
            _buildListTile(
              context,
              'Lock Screen / Session',
              (currentUser?.pinEnabled == true &&
                      currentUser?.pinHash != null &&
                      currentUser!.pinHash!.isNotEmpty)
                  ? 'Lock terminal immediately (unlock with your 4-digit PIN)'
                  : 'Lock the current terminal session',
              Icons.lock_outline,
              () async {
                final user = ref.read(currentUserProvider);
                await ref
                    .read(authRepositoryProvider)
                    .lockSession(userId: user?.id);
                ref.read(currentUserProvider.notifier).state = null;
                if (context.mounted) {
                  context.go('/login?locked=1');
                }
              },
            ),
          ]),
          if (currentUser?.canManageSystemData == true) ...[
            const SizedBox(height: 16),
            _buildSection(
              context,
              currentUser?.isSuperAdmin == true
                  ? 'Super Admin Configuration'
                  : 'Clinic Configuration',
              [
                if (currentUser?.isSuperAdmin == true) ...[
                  _buildListTile(
                    context,
                    'System Identity & Master Branding',
                    'Configure platform title, system logo, health authority organization, and global security policies',
                    Icons.branding_watermark_outlined,
                    () => _showSuperAdminConfigDialog(context, ref),
                  ),
                ] else ...[
                  _buildListTile(
                    context,
                    'Clinic / RHU Facility Profile',
                    'Configure clinic name, contact details, operating hours, and patient ID format',
                    Icons.local_hospital_outlined,
                    () => _showClinicConfigDialog(context, ref),
                  ),
                ],
                if (currentUser?.canManageStaffAccounts == true &&
                    currentUser?.isSuperAdmin != true)
                  _buildListTile(
                    context,
                    'Clinic Staff & Personnel Directory',
                    'Manage clinical staff, nurses, and local health facility users',
                    Icons.badge_outlined,
                    () => context.go('/staff'),
                  ),
              ],
            ),
          ],
          if (currentUser?.isSuperAdmin != true) ...[
            const SizedBox(height: 16),
            _buildSection(context, 'Backup & Synchronization', [
              _buildListTile(
                context,
                'Sync Management',
                'Monitor cloud sync status and trigger manual synchronization',
                Icons.cloud_sync_outlined,
                currentUser?.canManageBackupSync == true
                    ? () => context.go('/sync')
                    : currentUser?.canSyncRecords == true
                    ? () => context.go('/sync')
                    : null,
              ),
            ]),
          ],
          const SizedBox(height: 16),
          _buildSection(context, 'Database', [
            _buildListTile(
              context,
              'Backup Database',
              'Create a manual backup of all data',
              Icons.backup,
              currentUser?.canManageSystemData == true
                  ? () => _showBackupDialog(context, ref)
                  : null,
            ),
            _buildListTile(
              context,
              'Restore Database',
              'Restore from a previous backup',
              Icons.restore,
              currentUser?.canManageSystemData == true
                  ? () => _showRestoreDialog(context, ref)
                  : null,
            ),
            _buildListTile(
              context,
              'Database Statistics',
              'View database size and record counts',
              Icons.storage,
              () => _showStatisticsDialog(context, ref),
            ),
          ]),
          const SizedBox(height: 16),
          settingsAsync.when(
            skipLoadingOnReload: true,
            data: (settings) => _buildSection(context, 'System Information', [
              _buildInfoTile(context, 'App Version', settings.appVersion),
              _buildInfoTile(
                context,
                'Database Version',
                settings.databaseVersion,
              ),
              _buildInfoTile(
                context,
                'Last Sync',
                settings.lastSync != null
                    ? _formatDateTime(settings.lastSync!)
                    : 'Never',
              ),
            ]),
            loading: () => const LoadingState(),
            error: (error, _) => AppErrorState(
              title: 'System information could not be loaded',
              error: error,
              onRetry: () => ref.invalidate(settingsDataProvider),
            ),
          ),
          if (currentUser?.canManageSystemData == true) ...[
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: context.semanticColors.criticalBg,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: context.semanticColors.critical.withValues(
                    alpha: 0.35,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Danger Zone',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.semanticColors.critical,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever,
                      color: context.semanticColors.critical,
                    ),
                    title: Text(
                      'Clear All Data',
                      style: TextStyle(
                        color: context.semanticColors.critical,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'This will permanently delete all local data',
                    ),
                    onTap: () => _showClearDataDialog(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return formatDateTime12h(dateTime);
  }

  Widget _buildAppearanceSection(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentAccentTheme = ref.watch(accentThemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
          child: Text(
            'Appearance & Theme',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardSurface : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme Mode',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select your preferred display mode or match your operating system.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                segments: const [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined, size: 16),
                    label: Text('Light', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined, size: 16),
                    label: Text('Dark', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_brightness_outlined, size: 16),
                    label: Text('System', style: TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {currentThemeMode},
                onSelectionChanged: (newSelection) {
                  ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(newSelection.first);
                },
              ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: isDark ? AppColors.borderSubtle : const Color(0xFFF1F5F9),
              ),
              const SizedBox(height: 16),
              Text(
                'Clinical Accent Theme',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose an accent palette for navigation, buttons, and active indicators.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppAccentTheme.values.map((accent) {
                  final isSelected = accent == currentAccentTheme;
                  return InkWell(
                    onTap: () {
                      ref
                          .read(accentThemeProvider.notifier)
                          .setAccentTheme(accent);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 104,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent.primaryColor.withValues(alpha: 0.1)
                            : (isDark ? AppColors.inputSurface : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? accent.primaryColor
                              : (isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1)),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: accent.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            accent.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? accent.primaryColor
                                  : (isDark ? AppColors.textPrimary : const Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardSurface : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark ? AppColors.borderSubtle : const Color(0xFFF1F5F9),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        icon,
        size: 18,
        color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
      ),
      minLeadingWidth: 20,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 18,
        color: isDark ? AppColors.textSecondary : const Color(0xFF94A3B8),
      ),
      enabled: onTap != null,
      onTap: onTap,
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
        ),
      ),
    );
  }

  void _showBackupDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AppFormDialog(
        icon: Icons.backup_outlined,
        title: 'Backup Database',
        subtitle: 'Create a complete backup of all your EMR data',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInfoCard(
              icon: Icons.folder_outlined,
              label: 'Backup Location',
              value: 'Documents/MedSentry/Backups',
            ),
            const SizedBox(height: 16),
            const AppInfoCard(
              icon: Icons.dataset_outlined,
              label: 'Backup Contents',
              value:
                  'Patients, users, documents metadata, certificates, audit logs, and generated reports.',
            ),
          ],
        ),
        actions: [
          AppDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          AppDialogAction(
            label: 'Create Backup',
            isPrimary: true,
            icon: Icons.backup_outlined,
            onPressed: () async {
              try {
                final path = await ref.read(databaseProvider).createBackup();
                final currentUser = ref.read(currentUserProvider);
                await ref
                    .read(auditServiceProvider)
                    .log(
                      userId: currentUser?.id ?? 'system',
                      clinicId: currentUser?.clinicId,
                      action: AuditAction.backup,
                      entityType: 'database',
                      description:
                          'Created full system database backup ($path)',
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Backup created: $path')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Unable to create backup: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AppFormDialog(
        icon: Icons.restore_outlined,
        title: 'Restore Database',
        subtitle: 'Restore data from a previous backup',
        headerColor: context.semanticColors.warning,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppWarningCard(
              title: 'Restore Replaces Local Data',
              message:
                  'Restoring a backup will replace current local records. Create a backup first if you need to keep the current data.',
            ),
          ],
        ),
        actions: [
          AppDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          AppDialogAction(
            label: 'Choose Backup',
            isPrimary: true,
            icon: Icons.upload_file_outlined,
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['json'],
                allowMultiple: false,
                withData: true,
              );
              final file = result?.files.singleOrNull;
              final bytes = file?.bytes;
              if (bytes == null || bytes.isEmpty) return;

              if (!context.mounted) return;
              final confirmed = await _confirmRestore(context);
              if (!confirmed) return;

              try {
                await ref.read(databaseProvider).restoreFromBackup(bytes);
                final currentUser = ref.read(currentUserProvider);
                await ref
                    .read(auditServiceProvider)
                    .log(
                      userId: currentUser?.id ?? 'system',
                      clinicId: currentUser?.clinicId,
                      action: AuditAction.restore,
                      entityType: 'database',
                      description:
                          'Restored system database from backup (${file?.name ?? 'backup.json'})',
                    );
                await _refreshAfterRestore(ref);
                if (context.mounted) {
                  Navigator.pop(context);
                  AppNotification.success(
                    title: 'Backup Restored',
                    message: 'System database restored successfully.',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  AppNotification.error(
                    title: 'Restore Failed',
                    message: 'Unable to restore backup: $e',
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmRestore(BuildContext context) async {
    return await AppConfirmDialog.show(
      context,
      title: 'Restore Backup',
      message:
          'Restoring this backup will replace the current local data. Continue?',
      confirmLabel: 'Restore Data',
      cancelLabel: 'Cancel',
      type: ConfirmDialogType.warning,
      isDestructive: true,
      icon: Icons.restore_outlined,
    );
  }

  void _refreshAllProviders(WidgetRef ref) {
    ref.invalidate(settingsDataProvider);
    ref.invalidate(usersProvider);
    ref.invalidate(patientsProvider);
    ref.invalidate(documentsProvider);
    ref.invalidate(issuedCertificatesProvider);
    ref.invalidate(reportStatsProvider);
    ref.invalidate(generatedReportsProvider);
  }

  Future<void> _refreshAfterRestore(WidgetRef ref) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      final refreshedUser = await ref
          .read(authRepositoryProvider)
          .getUserById(currentUser.id);
      ref.read(currentUserProvider.notifier).state = refreshedUser;
    }
    _refreshAllProviders(ref);
  }

  void _showStatisticsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, dialogRef, _) {
          final settingsAsync = dialogRef.watch(settingsDataProvider);
          return settingsAsync.when(
            skipLoadingOnReload: true,
            data: (settings) => AppFormDialog(
              icon: Icons.storage_outlined,
              title: 'Database Statistics',
              subtitle: 'Overview of your EMR database',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppInfoCard(
                    icon: Icons.people_outline,
                    label: 'Total Patients',
                    value: settings.databaseStats.patientCount.toString(),
                    iconColor: context.semanticColors.info,
                  ),
                  const SizedBox(height: 12),
                  AppInfoCard(
                    icon: Icons.folder_outlined,
                    label: 'Total Documents',
                    value: settings.databaseStats.documentCount.toString(),
                    iconColor: context.semanticColors.warning,
                  ),
                  const SizedBox(height: 12),
                  AppInfoCard(
                    icon: Icons.data_usage_outlined,
                    label: 'Database Size',
                    value: settings.databaseStats.databaseSize,
                    iconColor: context.theme.colorScheme.tertiary,
                  ),
                  const SizedBox(height: 12),
                  AppInfoCard(
                    icon: Icons.backup_outlined,
                    label: 'Last Backup',
                    value: settings.databaseStats.lastBackup != null
                        ? _formatDateTime(settings.databaseStats.lastBackup!)
                        : 'Never',
                    iconColor: context.theme.colorScheme.secondary,
                  ),
                ],
              ),
              actions: [
                AppDialogAction(
                  label: 'Close',
                  isPrimary: true,
                  icon: Icons.check,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            loading: () => const AppFormDialog(
              icon: Icons.storage_outlined,
              title: 'Database Statistics',
              isLoading: true,
              loadingText: 'Loading statistics...',
              content: SizedBox.shrink(),
            ),
            error: (error, _) => AppFormDialog(
              icon: Icons.storage_outlined,
              title: 'Database Statistics',
              content: AppErrorState(
                title: 'System statistics could not be loaded',
                error: error,
                onRetry: () => dialogRef.invalidate(settingsDataProvider),
              ),
              actions: [
                AppDialogAction(
                  label: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSettingsLoadFeedback(
    BuildContext context, {
    required String message,
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: onRetry == null
              ? null
              : SnackBarAction(label: 'Retry', onPressed: onRetry),
        ),
      );
  }

  void _showSuperAdminConfigDialog(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.read(systemSettingsProvider);

    settingsAsync.when(
      data: (settings) {
        final appNameController = TextEditingController(text: settings.appName);
        final appTaglineController = TextEditingController(
          text: settings.appTagline,
        );
        final orgNameController = TextEditingController(
          text: settings.organizationName,
        );
        var logoDataUri = settings.logoDataUri;
        var sessionTimeout = settings.sessionTimeoutMinutes;
        var minPasswordLength = settings.passwordMinLength;
        var requireStrongPassword = settings.requireStrongPassword;
        var autoSyncEnabled = settings.autoSyncEnabled;
        var autoSyncInterval = settings.autoSyncIntervalMinutes;
        var dataRetentionDays = settings.dataRetentionDays;

        Future<void> chooseLogo(
          BuildContext dialogContext,
          void Function(void Function()) updateDialog,
        ) async {
          try {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
              withData: true,
            );
            if (result == null || result.files.isEmpty) return;

            final file = result.files.single;
            if (file.size > 10 * 1024 * 1024) {
              throw const FormatException(
                'Choose an image smaller than 10 MB.',
              );
            }
            final bytes = file.bytes;
            if (bytes == null || bytes.isEmpty) {
              throw const FormatException(
                'The selected image could not be read.',
              );
            }

            final extension = file.extension?.toLowerCase();
            final mimeType = switch (extension) {
              'png' => 'image/png',
              'jpg' || 'jpeg' => 'image/jpeg',
              'webp' => 'image/webp',
              _ => throw const FormatException(
                'Choose a PNG, JPG, or WebP image.',
              ),
            };
            updateDialog(() {
              logoDataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';
            });
          } catch (error, stackTrace) {
            debugPrint('Could not select logo: $error\n$stackTrace');
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text('Could not select logo: $error')),
              );
            }
          }
        }

        showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) => AppFormDialog(
              icon: Icons.branding_watermark_outlined,
              title: 'Super Admin Configuration',
              subtitle:
                  'System identity, master branding, platform security, and defaults',
              maxWidth: 700,
              content: SizedBox(
                height: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Master Branding & System Identity',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        label: 'Application Name',
                        hint: 'e.g. MedSentry',
                        field: TextField(
                          controller: appNameController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        label: 'System Motto / Tagline',
                        hint: 'e.g. Rural Health Unit Information System',
                        field: TextField(
                          controller: appTaglineController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        label: 'Managing Health Authority / Ministry',
                        hint: 'e.g. Department of Health - Caraga Region',
                        field: TextField(
                          controller: orgNameController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Master Platform Logo',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SystemLogo(
                            dataUri: logoDataUri,
                            size: 72,
                            backgroundColor: Theme.of(
                              ctx,
                            ).colorScheme.surfaceContainerHighest,
                            iconColor: Theme.of(ctx).colorScheme.primary,
                            iconSize: 36,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Displayed on login screens, navigation headers, browser tabs, and official reports across all terminals.',
                                  style: Theme.of(ctx).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          chooseLogo(ctx, setDialogState),
                                      icon: const Icon(Icons.upload_outlined),
                                      label: const Text('Choose Logo'),
                                    ),
                                    if (logoDataUri.isNotEmpty)
                                      TextButton(
                                        onPressed: () => setDialogState(
                                          () => logoDataUri = '',
                                        ),
                                        child: const Text('Reset to Default'),
                                      ),
                                  ],
                                ),
                                Text(
                                  'PNG, JPG, or WebP; maximum 10 MB.',
                                  style: Theme.of(ctx).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'Platform Security & Authentication Policies',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppFormField(
                              label: 'Inactivity Lock Timeout',
                              field: DropdownButtonFormField<int>(
                                initialValue:
                                    [
                                      15,
                                      30,
                                      60,
                                      240,
                                      480,
                                    ].contains(sessionTimeout)
                                    ? sessionTimeout
                                    : 480,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 15,
                                    child: Text('15 Minutes'),
                                  ),
                                  DropdownMenuItem(
                                    value: 30,
                                    child: Text('30 Minutes'),
                                  ),
                                  DropdownMenuItem(
                                    value: 60,
                                    child: Text('1 Hour'),
                                  ),
                                  DropdownMenuItem(
                                    value: 240,
                                    child: Text('4 Hours'),
                                  ),
                                  DropdownMenuItem(
                                    value: 480,
                                    child: Text('8 Hours (Shift End)'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => sessionTimeout = val);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppFormField(
                              label: 'Min Password Length',
                              field: DropdownButtonFormField<int>(
                                initialValue:
                                    [8, 10, 12].contains(minPasswordLength)
                                    ? minPasswordLength
                                    : 8,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 8,
                                    child: Text('8 Characters'),
                                  ),
                                  DropdownMenuItem(
                                    value: 10,
                                    child: Text('10 Characters'),
                                  ),
                                  DropdownMenuItem(
                                    value: 12,
                                    child: Text('12 Characters'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(
                                      () => minPasswordLength = val,
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Require Strong Passwords'),
                        subtitle: const Text(
                          'Enforce mixed case, numbers, and symbols for all accounts',
                        ),
                        value: requireStrongPassword,
                        onChanged: (val) =>
                            setDialogState(() => requireStrongPassword = val),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'Cloud Sync & Gateway Defaults',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Automatic Background Synchronization',
                        ),
                        subtitle: const Text(
                          'Periodically push changes and pull remote clinic updates',
                        ),
                        value: autoSyncEnabled,
                        onChanged: (val) =>
                            setDialogState(() => autoSyncEnabled = val),
                      ),
                      if (autoSyncEnabled) ...[
                        const SizedBox(height: 8),
                        AppFormField(
                          label: 'Background Sync Interval',
                          field: DropdownButtonFormField<int>(
                            initialValue:
                                [15, 30, 60].contains(autoSyncInterval)
                                ? autoSyncInterval
                                : 30,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 15,
                                child: Text('Every 15 Minutes'),
                              ),
                              DropdownMenuItem(
                                value: 30,
                                child: Text('Every 30 Minutes'),
                              ),
                              DropdownMenuItem(
                                value: 60,
                                child: Text('Every 60 Minutes'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => autoSyncInterval = val);
                              }
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'Compliance & Data Retention',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppFormField(
                        label: 'Audit Log Retention Policy',
                        field: DropdownButtonFormField<int>(
                          initialValue:
                              [365, 730, 2555].contains(dataRetentionDays)
                              ? dataRetentionDays
                              : 365,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 365,
                              child: Text('1 Year (365 Days)'),
                            ),
                            DropdownMenuItem(
                              value: 730,
                              child: Text('2 Years (730 Days)'),
                            ),
                            DropdownMenuItem(
                              value: 2555,
                              child: Text('7 Years (DOH Standard)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => dataRetentionDays = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                AppDialogAction(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(ctx),
                ),
                AppDialogAction(
                  label: 'Save Super Admin Settings',
                  isPrimary: true,
                  onPressed: () async {
                    final nextSettings = settings.copyWith(
                      appName: appNameController.text.trim().isEmpty
                          ? 'MedSentry'
                          : appNameController.text.trim(),
                      appTagline: appTaglineController.text.trim(),
                      organizationName: orgNameController.text.trim(),
                      logoDataUri: logoDataUri,
                      sessionTimeoutMinutes: sessionTimeout,
                      passwordMinLength: minPasswordLength,
                      requireStrongPassword: requireStrongPassword,
                      autoSyncEnabled: autoSyncEnabled,
                      autoSyncIntervalMinutes: autoSyncInterval,
                      dataRetentionDays: dataRetentionDays,
                    );
                    await ref
                        .read(databaseProvider)
                        .updateSystemSettings(nextSettings);
                    final currentUser = ref.read(currentUserProvider);
                    await ref
                        .read(auditServiceProvider)
                        .log(
                          userId: currentUser?.id ?? 'system',
                          clinicId: currentUser?.clinicId,
                          action: AuditAction.settingsChange,
                          entityType: 'system_settings',
                          entityId: 'super_admin_config',
                          description:
                              'Updated Super Admin system branding & platform settings (${nextSettings.appName})',
                        );
                    ref.invalidate(systemSettingsProvider);
                    final syncResult = await ref
                        .read(syncServiceProvider)
                        .startSync();
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            syncResult.success
                                ? 'Super Admin configuration saved and synchronized.'
                                : 'Settings saved locally; cloud sync was not completed: ${syncResult.message}',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ).whenComplete(() {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            appNameController.dispose();
            appTaglineController.dispose();
            orgNameController.dispose();
          });
        });
      },
      loading: () => _showSettingsLoadFeedback(
        context,
        message: 'System settings are still loading. Try again shortly.',
      ),
      error: (error, _) {
        debugPrint('Failed to load Super Admin settings: $error');
        _showSettingsLoadFeedback(
          context,
          message: 'Super Admin settings could not be loaded.',
          onRetry: () => _showSuperAdminConfigDialog(context, ref),
        );
      },
    );
  }

  void _showClinicConfigDialog(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.read(systemSettingsProvider);

    settingsAsync.when(
      data: (settings) {
        final clinicNameController = TextEditingController(
          text: settings.clinicName,
        );
        final clinicTypeController = TextEditingController(
          text: settings.clinicType,
        );
        final clinicCodeController = TextEditingController(
          text: settings.clinicCode,
        );
        final clinicAddressController = TextEditingController(
          text: settings.clinicAddress,
        );
        final clinicContactController = TextEditingController(
          text: settings.clinicContact,
        );
        final municipalityController = TextEditingController(
          text: settings.municipality,
        );
        final provinceController = TextEditingController(
          text: settings.province,
        );
        final operatingHoursController = TextEditingController(
          text: settings.operatingHours,
        );
        final idPrefixController = TextEditingController(
          text: settings.patientIdPrefix,
        );
        final servicesController = TextEditingController(
          text: settings.serviceTypes.join(', '),
        );
        final categoriesController = TextEditingController(
          text: settings.patientCategories.join(', '),
        );
        var certificatesEnabled = settings.certificatesModuleEnabled;
        var syncEnabled = settings.syncModuleEnabled;

        showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) => AppFormDialog(
              icon: Icons.local_hospital_outlined,
              title: 'Clinic / RHU Configuration',
              subtitle:
                  'Configure your local facility details, patient ID prefix, and services',
              maxWidth: 680,
              content: SizedBox(
                height: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Facility Profile',
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        label: 'Clinic / RHU Name',
                        field: TextField(
                          controller: clinicNameController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppFormField(
                              label: 'Facility Type',
                              field: TextField(
                                controller: clinicTypeController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g., Rural Health Unit',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppFormField(
                              label: 'Clinic Code',
                              field: TextField(
                                controller: clinicCodeController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g., RHU-001',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        label: 'Facility Address',
                        field: TextField(
                          controller: clinicAddressController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppFormField(
                              label: 'Municipality / City',
                              field: TextField(
                                controller: municipalityController,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppFormField(
                              label: 'Province / Region',
                              field: TextField(
                                controller: provinceController,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        label: 'Official Contact Number',
                        field: TextField(
                          controller: clinicContactController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        label: 'Operating Hours',
                        field: TextField(
                          controller: operatingHoursController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Services & Patient Categories',
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        label: 'Services',
                        hint: 'Separate services with commas',
                        field: TextField(
                          controller: servicesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        label: 'Patient Categories',
                        hint: 'Separate categories with commas',
                        field: TextField(
                          controller: categoriesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Enabled Facility Modules',
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Certificate Generation'),
                        value: certificatesEnabled,
                        onChanged: (value) =>
                            setDialogState(() => certificatesEnabled = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Cloud & LAN Sync'),
                        value: syncEnabled,
                        onChanged: (value) =>
                            setDialogState(() => syncEnabled = value),
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        label: 'Patient ID Prefix',
                        field: TextField(
                          controller: idPrefixController,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            helperText:
                                'Next ID: ${settings.generateNextPatientId()}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                AppDialogAction(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(ctx),
                ),
                AppDialogAction(
                  label: 'Save Clinic Settings',
                  isPrimary: true,
                  onPressed: () async {
                    final nextSettings = settings.copyWith(
                      clinicName: clinicNameController.text.trim(),
                      clinicType: clinicTypeController.text.trim(),
                      clinicCode: clinicCodeController.text.trim(),
                      clinicAddress: clinicAddressController.text.trim(),
                      clinicContact: clinicContactController.text.trim(),
                      municipality: municipalityController.text.trim(),
                      province: provinceController.text.trim(),
                      operatingHours: operatingHoursController.text.trim(),
                      patientIdPrefix: idPrefixController.text.trim(),
                      serviceTypes: _commaSeparatedValues(
                        servicesController.text,
                      ),
                      patientCategories: _commaSeparatedValues(
                        categoriesController.text,
                      ),
                      certificatesModuleEnabled: certificatesEnabled,
                      syncModuleEnabled: syncEnabled,
                    );
                    await ref
                        .read(databaseProvider)
                        .updateSystemSettings(nextSettings);
                    final currentUser = ref.read(currentUserProvider);
                    await ref
                        .read(auditServiceProvider)
                        .log(
                          userId: currentUser?.id ?? 'system',
                          clinicId: currentUser?.clinicId,
                          action: AuditAction.settingsChange,
                          entityType: 'system_settings',
                          entityId: 'clinic_profile',
                          description:
                              'Updated clinic configuration (${nextSettings.clinicName})',
                        );
                    ref.invalidate(systemSettingsProvider);
                    final syncResult = await ref
                        .read(syncServiceProvider)
                        .startSync();
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            syncResult.success
                                ? 'Clinic settings saved and synchronized.'
                                : 'Settings saved locally; cloud sync was not completed: ${syncResult.message}',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ).whenComplete(() {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            clinicNameController.dispose();
            clinicTypeController.dispose();
            clinicCodeController.dispose();
            clinicAddressController.dispose();
            clinicContactController.dispose();
            municipalityController.dispose();
            provinceController.dispose();
            operatingHoursController.dispose();
            idPrefixController.dispose();
            servicesController.dispose();
            categoriesController.dispose();
          });
        });
      },
      loading: () => _showSettingsLoadFeedback(
        context,
        message: 'Clinic settings are still loading. Try again shortly.',
      ),
      error: (error, _) {
        debugPrint('Failed to load clinic details: $error');
        _showSettingsLoadFeedback(
          context,
          message: 'Clinic details could not be loaded.',
          onRetry: () => _showClinicConfigDialog(context, ref),
        );
      },
    );
  }

  List<String> _commaSeparatedValues(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  void _showClearDataDialog(BuildContext context, WidgetRef ref) {
    final confirmationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AppFormDialog(
        icon: Icons.delete_forever_outlined,
        title: 'Clear All Data',
        subtitle: 'Permanently delete all application data',
        headerColor: context.semanticColors.critical,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppWarningCard(
              title: 'This Action Cannot Be Undone',
              message:
                  'This will permanently delete ALL data from the application including patient records, documents, and settings. Make sure you have created a backup before proceeding.',
            ),
            const SizedBox(height: 20),
            AppFormField(
              label: 'Type "DELETE" to confirm',
              hint: 'Required for destructive actions',
              required: true,
              field: TextField(
                controller: confirmationController,
                decoration: const InputDecoration(
                  hintText: 'Type DELETE to confirm',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          AppDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          AppDialogAction(
            label: 'I Understand, Delete All',
            isPrimary: true,
            isDestructive: true,
            icon: Icons.delete_forever,
            onPressed: () {
              if (confirmationController.text.trim() != 'DELETE') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Type DELETE to confirm data clearing.'),
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _confirmClearData(context, ref);
            },
          ),
        ],
      ),
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        confirmationController.dispose();
      });
    });
  }

  void _confirmClearData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AppFormDialog(
        icon: Icons.delete_forever_outlined,
        title: 'Clearing All Data',
        isLoading: true,
        loadingText: 'Permanently deleting all data...',
        content: SizedBox.shrink(),
      ),
    );

    Future<void>(() async {
      await ref.read(databaseProvider).clearAll();
      ref.invalidate(patientsProvider);
      ref.invalidate(documentsProvider);
      ref.read(currentUserProvider.notifier).state = null;

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All data has been cleared'),
            backgroundColor: context.semanticColors.critical,
          ),
        );
        context.go('/login');
      }
    });
  }
}

class StaffManagementPanel extends ConsumerStatefulWidget {
  final VoidCallback onAddUser;
  final void Function(User user) onEditUser;
  final void Function(User user) onDeactivateUser;
  final void Function(User user) onDeleteUser;
  final bool embedded;

  const StaffManagementPanel({
    super.key,
    required this.onAddUser,
    required this.onEditUser,
    required this.onDeactivateUser,
    required this.onDeleteUser,
    this.embedded = false,
  });

  @override
  ConsumerState<StaffManagementPanel> createState() =>
      _StaffManagementPanelState();
}

class _StaffManagementPanelState extends ConsumerState<StaffManagementPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String?
  _selectedClinicFilter; // null = All, '__unassigned__' = Unassigned, or clinicId

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildTabContent(
    User? currentUser,
    AsyncValue<List<User>> usersAsync,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clinics = ref.watch(clinicsProvider).valueOrNull ?? <Clinic>[];
    final tabView = usersAsync.when(
      skipLoadingOnReload: true,
      data: (users) {
        final query = _searchQuery.trim().toLowerCase();
        final phoneQuery = query.replaceAll(RegExp(r'\D'), '');
        final scopedUsers = users.where((u) {
          if (currentUser == null) return false;

          if (!currentUser.isSuperAdmin) {
            // Administrators only manage accounts within their assigned RHU clinic.
            // Super administrators must NEVER be displayed or managed in clinic staff views.
            if (u.role == UserRole.superAdmin) return false;

            // Always display the currentUser's own account
            if (u.id != currentUser.id) {
              // If current user is assigned to an RHU, allow accounts assigned to the same RHU
              // OR unassigned accounts (so administrators can view and manage unassigned personnel)
              if (currentUser.clinicId != null &&
                  u.clinicId != null &&
                  u.clinicId != currentUser.clinicId) {
                return false;
              }
            }
          } else {
            // Super Administrator facility filter
            if (_selectedClinicFilter != null) {
              if (_selectedClinicFilter == '__unassigned__') {
                if (u.clinicId != null) return false;
              } else if (u.clinicId != _selectedClinicFilter) {
                return false;
              }
            }
          }

          if (query.isEmpty) return true;
          final clinic = clinics.where((c) => c.id == u.clinicId).firstOrNull;
          final clinicMatches =
              clinic != null &&
              (clinic.name.toLowerCase().contains(query) ||
                  clinic.code.toLowerCase().contains(query));
          final unassignedMatches =
              u.clinicId == null && 'unassigned'.contains(query);

          return u.fullName.toLowerCase().contains(query) ||
              u.email.toLowerCase().contains(query) ||
              u.roleDisplay.toLowerCase().contains(query) ||
              clinicMatches ||
              unassignedMatches ||
              (u.contactNumber?.toLowerCase().contains(query) ?? false) ||
              (phoneQuery.isNotEmpty &&
                  (u.contactNumber ?? '')
                      .replaceAll(RegExp(r'\D'), '')
                      .contains(phoneQuery));
        }).toList();

        return TabBarView(
          controller: _tabController,
          children: [
            _StaffAccountsTab(
              users: scopedUsers.where((u) => u.isActive).toList(),
              currentUser: currentUser,
              emptyMessage: 'No active user accounts.',
              showAddButton: true,
              onAddUser: widget.onAddUser,
              onEditUser: widget.onEditUser,
              onDeactivateUser: widget.onDeactivateUser,
              onDeleteUser: widget.onDeleteUser,
            ),
            _StaffAccountsTab(
              users: scopedUsers.where((u) => !u.isActive).toList(),
              currentUser: currentUser,
              emptyMessage: 'No inactive accounts.',
              showAddButton: false,
              onAddUser: widget.onAddUser,
              onEditUser: widget.onEditUser,
              onDeactivateUser: widget.onDeactivateUser,
              onDeleteUser: widget.onDeleteUser,
            ),
          ],
        );
      },
      loading: () => const LoadingState(),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unable to load users.'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(usersProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );

    final isSuperAdmin = currentUser?.isSuperAdmin == true;
    final activeUsersList = (usersAsync.valueOrNull ?? <User>[])
        .where((user) => user.isActive)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search & Refresh Row
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search users by name, email, phone, or role...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 16,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                      ),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.clear, size: 14),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.inputSurface : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  tooltip: 'Refresh staff accounts',
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                  ),
                  onPressed: () => ref.invalidate(usersProvider),
                ),
              ),
            ],
          ),
        ),

        // Facility Filter Chips for Super Admin
        if (isSuperAdmin) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All Facilities (${activeUsersList.length})'),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: _selectedClinicFilter == null
                          ? AppColors.primaryEmerald
                          : (isDark ? AppColors.textSecondary : const Color(0xFF64748B)),
                    ),
                    selected: _selectedClinicFilter == null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    side: BorderSide(
                      color: _selectedClinicFilter == null
                          ? AppColors.primaryEmerald
                          : (isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1)),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedClinicFilter = null);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Unassigned (${activeUsersList.where((u) => u.clinicId == null).length})',
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: _selectedClinicFilter == '__unassigned__'
                          ? AppColors.primaryEmerald
                          : (isDark ? AppColors.textSecondary : const Color(0xFF64748B)),
                    ),
                    selected: _selectedClinicFilter == '__unassigned__',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    side: BorderSide(
                      color: _selectedClinicFilter == '__unassigned__'
                          ? AppColors.primaryEmerald
                          : (isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1)),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedClinicFilter = selected
                            ? '__unassigned__'
                            : null;
                      });
                    },
                  ),
                  ...clinics.map((clinic) {
                    final clinicCount = activeUsersList
                        .where((u) => u.clinicId == clinic.id)
                        .length;
                    final isSelected = _selectedClinicFilter == clinic.id;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text('${clinic.name} ($clinicCount)'),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: isSelected
                              ? AppColors.primaryEmerald
                              : (isDark ? AppColors.textSecondary : const Color(0xFF64748B)),
                        ),
                        selected: isSelected,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primaryEmerald
                              : (isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1)),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedClinicFilter = selected ? clinic.id : null;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],

        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: isDark ? AppColors.cardSurface : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                width: 1,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            labelColor: isDark ? AppColors.primaryEmerald : const Color(0xFF0F766E),
            unselectedLabelColor: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Active Accounts'),
              Tab(text: 'Inactive Accounts'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (widget.embedded)
          Expanded(child: tabView)
        else
          SizedBox(height: 420, child: tabView),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final currentUser = ref.watch(currentUserProvider);
    final content = _buildTabContent(currentUser, usersAsync);

    if (widget.embedded) return content;

    return AppFormDialog(
      icon: Icons.admin_panel_settings_outlined,
      title: 'Users',
      subtitle: 'Manage user accounts, roles, and access permissions',
      maxWidth: 860,
      content: content,
      actions: [
        AppDialogAction(
          label: 'Close',
          isPrimary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _StaffAccountsTab extends StatelessWidget {
  final List<User> users;
  final User? currentUser;
  final String emptyMessage;
  final bool showAddButton;
  final VoidCallback onAddUser;
  final void Function(User user) onEditUser;
  final void Function(User user) onDeactivateUser;
  final void Function(User user) onDeleteUser;

  const _StaffAccountsTab({
    required this.users,
    required this.currentUser,
    required this.emptyMessage,
    required this.showAddButton,
    required this.onAddUser,
    required this.onEditUser,
    required this.onDeactivateUser,
    required this.onDeleteUser,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAddButton)
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onAddUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
              label: const Text('Add User', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        if (showAddButton) const SizedBox(height: 12),
        Expanded(
          child: users.isEmpty
              ? Center(
                  child: AppInfoCard(
                    icon: Icons.people_outline,
                    label: 'No Users',
                    value: emptyMessage,
                  ),
                )
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _UserManagementTile(
                      user: user,
                      currentUser: currentUser,
                      onEdit: () => onEditUser(user),
                      onDeactivate: user.isActive
                          ? () => onDeactivateUser(user)
                          : null,
                      onDelete: () => onDeleteUser(user),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AdminResetPasswordDialog extends StatefulWidget {
  final User user;
  final User currentUser;
  final Future<void> Function(String newPassword) onConfirmReset;

  const _AdminResetPasswordDialog({
    required this.user,
    required this.currentUser,
    required this.onConfirmReset,
  });

  @override
  State<_AdminResetPasswordDialog> createState() =>
      _AdminResetPasswordDialogState();
}

class _AdminResetPasswordDialogState extends State<_AdminResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.onConfirmReset(_passwordController.text.trim());
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset password: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      icon: Icons.lock_reset_outlined,
      title: 'Reset User Password',
      subtitle:
          'Set a new temporary password for ${widget.user.fullName} (${widget.user.email})',
      maxWidth: 480,
      isLoading: _isSaving,
      loadingText: 'Resetting password...',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInfoCard(
              icon: Icons.shield_outlined,
              label: 'Administrative Security Reset',
              value:
                  'As an authorized administrator, you are updating the password for ${widget.user.fullName}. Password must be at least 8 characters long with letters and numbers.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'New Password *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _isPasswordVisible
                      ? 'Hide password'
                      : 'Show password',
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (val) {
                final text = val?.trim() ?? '';
                if (text.isEmpty) return 'New password is required.';
                if (text.length < 8) {
                  return 'Password must be at least 8 characters long.';
                }
                if (!RegExp(r'[A-Za-z]').hasMatch(text) ||
                    !RegExp(r'[0-9]').hasMatch(text)) {
                  return 'Must include both letters and numbers.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: !_isPasswordVisible,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (val) {
                if (val?.trim() != _passwordController.text.trim()) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        AppDialogAction(
          label: 'Cancel',
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: 'Reset Password',
          isPrimary: true,
          icon: Icons.check,
          onPressed: _isSaving ? null : _submit,
        ),
      ],
    );
  }
}

class _UserManagementTile extends ConsumerWidget {
  final User user;
  final User? currentUser;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback onDelete;

  const _UserManagementTile({
    required this.user,
    required this.currentUser,
    required this.onEdit,
    required this.onDeactivate,
    required this.onDelete,
  });

  bool get canEdit {
    if (currentUser == null) return false;
    if (!currentUser!.canEditUserProfiles) return false;
    if (currentUser!.isSuperAdmin) return true;
    if (user.role == UserRole.superAdmin) return false;
    if (currentUser!.clinicId != null &&
        user.clinicId != currentUser!.clinicId) {
      return false;
    }
    return true;
  }

  bool get canResetPassword {
    if (currentUser == null) return false;
    if (!currentUser!.canResetUserPasswords) return false;
    if (currentUser!.isSuperAdmin) return true;
    if (user.role == UserRole.superAdmin) return false;
    if (currentUser!.clinicId != null &&
        user.clinicId != currentUser!.clinicId) {
      return false;
    }
    return true;
  }

  bool get canDeactivate {
    if (currentUser == null) return false;
    if (user.id == currentUser!.id) return false;
    if (currentUser!.isSuperAdmin) return true;
    if (user.role == UserRole.superAdmin) return false;
    if (currentUser!.clinicId != null &&
        user.clinicId != currentUser!.clinicId) {
      return false;
    }
    return true;
  }

  bool get canDelete {
    if (currentUser == null || user.id == currentUser!.id) return false;
    if (!currentUser!.canManageStaffAccounts) return false;
    if (currentUser!.isSuperAdmin) return true;
    if (user.role == UserRole.superAdmin) return false;
    return currentUser!.clinicId == null ||
        user.clinicId == currentUser!.clinicId;
  }

  Future<void> _handleResetPassword(BuildContext context, WidgetRef ref) async {
    final curUser = currentUser;
    if (curUser == null) return;

    await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => _AdminResetPasswordDialog(
        user: user,
        currentUser: curUser,
        onConfirmReset: (newPassword) async {
          await ref
              .read(authRepositoryProvider)
              .adminResetUserPassword(
                targetUserId: user.id,
                newPassword: newPassword,
                actorUserId: curUser.id,
              );
          ref.invalidate(usersProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Password for ${user.fullName} has been reset.'),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (user.isReactivated) {
      return StatusBadge.info(text: 'Reactivated', showDot: true);
    } else if (user.isActive) {
      return StatusBadge.active(text: 'Active', showDot: true);
    } else {
      return StatusBadge.inactive(text: 'Inactive', showDot: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          UserAvatar(user: user, radius: 18, showStatusIndicator: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      user.fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: -0.2,
                        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                    _buildStatusBadge(),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        user.roleDisplay,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    if (currentUser?.isSuperAdmin == true) ...[
                      if (user.role == UserRole.superAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryEmerald.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.primaryEmerald.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, size: 11, color: AppColors.primaryEmerald),
                              SizedBox(width: 4),
                              Text(
                                'All Facilities',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryEmerald,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (user.clinicId != null) ...[
                        Builder(
                          builder: (context) {
                            final clinics = ref.watch(clinicsProvider).valueOrNull ?? <Clinic>[];
                            final clinic = clinics.where((c) => c.id == user.clinicId).firstOrNull;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.domain_outlined, size: 11, color: isDark ? AppColors.textSecondary : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    clinic?.name ?? clinic?.code ?? 'Assigned RHU',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.semanticColors.warningBg,
                            border: Border.all(
                              color: context.semanticColors.warning.withValues(alpha: 0.35),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 11,
                                color: context.semanticColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Unassigned Facility',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: context.semanticColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    if (user.id == currentUser?.id)
                      StatusBadge.info(text: 'Current User'),
                  ],
                ),
              ],
            ),
          ),
          if (context.isMobile)
            (canEdit ||
                    canResetPassword ||
                    (canDeactivate &&
                        user.isActive &&
                        onDeactivate != null) ||
                    canDelete)
                ? PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                    ),
                    tooltip: 'User options',
                    onSelected: (val) {
                      if (val == 'edit') onEdit();
                      if (val == 'reset_pwd') {
                        _handleResetPassword(context, ref);
                      }
                      if (val == 'deactivate') onDeactivate?.call();
                      if (val == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      if (canEdit)
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined, size: 18),
                            title: Text('Edit user', style: TextStyle(fontSize: 13)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      if (canResetPassword)
                        const PopupMenuItem(
                          value: 'reset_pwd',
                          child: ListTile(
                            leading: Icon(Icons.lock_reset_outlined, size: 18),
                            title: Text('Reset Password', style: TextStyle(fontSize: 13)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      if (canDeactivate &&
                          user.isActive &&
                          onDeactivate != null)
                        PopupMenuItem(
                          value: 'deactivate',
                          child: ListTile(
                            leading: Icon(
                              Icons.person_off_outlined,
                              size: 18,
                              color: context.semanticColors.warning,
                            ),
                            title: const Text('Deactivate', style: TextStyle(fontSize: 13)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      if (canDelete)
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: context.semanticColors.critical,
                            ),
                            title: const Text('Delete permanently', style: TextStyle(fontSize: 13)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                    ],
                  )
                : const SizedBox.shrink()
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canResetPassword)
                  IconButton(
                    tooltip: 'Reset Password (Reset PWD)',
                    icon: const Icon(Icons.lock_reset_outlined, size: 16),
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                    onPressed: () => _handleResetPassword(context, ref),
                  ),
                if (canEdit)
                  IconButton(
                    tooltip: 'Edit user',
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                    onPressed: onEdit,
                  ),
                if (canDeactivate && user.isActive && onDeactivate != null)
                  IconButton(
                    tooltip: 'Deactivate user',
                    icon: const Icon(Icons.person_off_outlined, size: 16),
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                    onPressed: onDeactivate,
                  ),
                if (canDelete)
                  IconButton(
                    tooltip: 'Delete user permanently',
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: context.semanticColors.critical,
                    onPressed: onDelete,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class StaffFormDialog extends ConsumerStatefulWidget {
  final User? existingUser;

  const StaffFormDialog({super.key, this.existingUser});

  @override
  ConsumerState<StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends ConsumerState<StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _specializationController = TextEditingController();
  final _licenseController = TextEditingController();
  final _pinController = TextEditingController();
  String? _profileImageUrl;
  UserRole _role = UserRole.staff;
  String? _clinicId;
  bool _isActive = true;
  bool _pinEnabled = false;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _isPasswordVisible = false;

  bool get _isEdit => widget.existingUser != null;

  void _markDirty() {
    if (!_isDirty && mounted) {
      setState(() => _isDirty = true);
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final picked = await DocumentService.pickImage();
      if (picked == null) return;
      final bytes = await picked.getBytes();
      final base64String = base64Encode(bytes);
      final mimeType = picked.extension == 'png' ? 'image/png' : 'image/jpeg';
      setState(() {
        _profileImageUrl = 'data:$mimeType;base64,$base64String';
        _isDirty = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to select profile picture: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final user = widget.existingUser;
    if (user != null) {
      _emailController.text = user.email;
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _contactController.text = user.contactNumber ?? '';
      _specializationController.text = user.specialization ?? '';
      _licenseController.text = user.licenseNumber ?? '';
      _profileImageUrl = user.profileImageUrl;
      _role = user.role;
      _clinicId = user.clinicId;
      _isActive = user.isActive;
      _pinEnabled = user.pinEnabled;
    } else {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser?.isSuperAdmin != true) {
        _clinicId = currentUser?.clinicId;
      }
    }

    _emailController.addListener(_markDirty);
    _passwordController.addListener(_markDirty);
    _firstNameController.addListener(_markDirty);
    _lastNameController.addListener(_markDirty);
    _contactController.addListener(_markDirty);
    _specializationController.addListener(_markDirty);
    _licenseController.addListener(_markDirty);
    _pinController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactController.dispose();
    _specializationController.dispose();
    _licenseController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleCancel() async {
    if (!_isDirty || _isSaving) {
      Navigator.of(context).pop(false);
      return;
    }
    final shouldDiscard = await confirmDiscardUnsavedChanges(context);
    if (shouldDiscard && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final clinicsAsync = ref.watch(clinicsProvider);
    final isSuperAdmin = currentUser?.isSuperAdmin == true;

    final availableRoles = isSuperAdmin
        ? UserRole.values
        : UserRole.values.where((r) => r != UserRole.superAdmin).toList();

    return PopScope(
      canPop: !_isDirty || _isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleCancel();
      },
      child: AppFormDialog(
        icon: _isEdit ? Icons.edit_outlined : Icons.person_add_alt_1,
        title: _isEdit ? 'Edit User Account' : 'Add User Account',
        subtitle: _isEdit
            ? 'Update profile, role, facility assignment, or password'
            : 'Register an administrator or staff user with role-scoped access',
        maxWidth: 720,
        onClose: _isSaving ? null : _handleCancel,
        isLoading: _isSaving,
        loadingText: _isEdit
            ? 'Saving user account...'
            : 'Creating user account...',
        content: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppFormSection(
                title: 'Profile Information',
                subtitle:
                    'Personal details, contact number, and professional credentials',
                icon: Icons.person_outline,
                child: Column(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Stack(
                          children: [
                            UserAvatar(
                              user:
                                  widget.existingUser?.copyWith(
                                    firstName:
                                        _firstNameController.text.isNotEmpty
                                        ? _firstNameController.text
                                        : 'New',
                                    lastName:
                                        _lastNameController.text.isNotEmpty
                                        ? _lastNameController.text
                                        : 'User',
                                    profileImageUrl: _profileImageUrl,
                                  ) ??
                                  User(
                                    id: 'temp',
                                    email: _emailController.text,
                                    firstName:
                                        _firstNameController.text.isNotEmpty
                                        ? _firstNameController.text
                                        : 'New',
                                    lastName:
                                        _lastNameController.text.isNotEmpty
                                        ? _lastNameController.text
                                        : 'User',
                                    role: _role,
                                    profileImageUrl: _profileImageUrl,
                                    isActive: true,
                                    pinEnabled: false,
                                  ),
                              radius: 36,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Material(
                                color: Theme.of(context).colorScheme.primary,
                                shape: const CircleBorder(),
                                elevation: 2,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _pickProfilePhoto,
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _field(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      enabled: !_isEdit || isSuperAdmin,
                      required: true,
                      keyboardType: TextInputType.emailAddress,
                      helperText: isSuperAdmin && _isEdit
                          ? 'Super Admin can update this staff member\'s login email address.'
                          : 'Verification codes (OTP) will be sent to this email address for Staff & Admin logins.',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _firstNameController,
                            label: 'First Name',
                            icon: Icons.person_outline,
                            required: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            controller: _lastNameController,
                            label: 'Last Name',
                            icon: Icons.person_outline,
                            required: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _contactController,
                      label: 'Contact Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      required: false,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _specializationController,
                      label: 'Specialization / Clinical Role',
                      icon: Icons.medical_services_outlined,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _licenseController,
                      label: 'Professional PRC License Number',
                      icon: Icons.credit_card_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppFormSection(
                title: 'Role & Facility Assignment',
                subtitle: 'Access privileges and RHU clinic facility boundary',
                icon: Icons.badge_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<UserRole>(
                      initialValue: availableRoles.contains(_role)
                          ? _role
                          : availableRoles.first,
                      decoration: const InputDecoration(
                        labelText: 'System Role *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: availableRoles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                      validator: (value) =>
                          value == null ? 'Select a system role.' : null,
                      onChanged: (value) {
                        if (value != null && value != _role) {
                          setState(() {
                            _role = value;
                            _isDirty = true;
                          });
                        }
                      },
                    ),
                    if (isSuperAdmin && _role != UserRole.superAdmin) ...[
                      const SizedBox(height: 16),
                      clinicsAsync.when(
                        skipLoadingOnReload: true,
                        data: (clinics) => DropdownButtonFormField<String?>(
                          initialValue: clinics.any((c) => c.id == _clinicId)
                              ? _clinicId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Assigned RHU Facility *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.domain_outlined),
                          ),
                          hint: const Text('Select RHU Facility'),
                          items: [
                            ...clinics.map(
                              (clinic) => DropdownMenuItem<String?>(
                                value: clinic.id,
                                child: Text('${clinic.name} (${clinic.code})'),
                              ),
                            ),
                          ],
                          validator: (val) {
                            if (_role != UserRole.superAdmin &&
                                (val == null || val.isEmpty)) {
                              return 'Please select an RHU facility';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            setState(() {
                              _clinicId = val;
                              _isDirty = true;
                            });
                          },
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (error, _) => AppErrorState(
                          title: 'Facility list could not be loaded',
                          error: error,
                          onRetry: () => ref.invalidate(clinicsProvider),
                        ),
                      ),
                    ] else if (!isSuperAdmin) ...[
                      const SizedBox(height: 16),
                      AppInfoCard(
                        icon: Icons.business_outlined,
                        label: 'Facility Scope (Multi-RHU Isolation)',
                        value: currentUser?.clinicId != null
                            ? 'Fixed to your active RHU clinic facility'
                            : 'Assigned to Platform Pool',
                      ),
                    ],
                    if (_isEdit) ...[
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active Account Status'),
                        subtitle: const Text(
                          'Inactive users cannot log in or perform actions in MedSentry',
                        ),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                            _isDirty = true;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppFormSection(
                title: 'Account Security & Credentials',
                subtitle: 'Initial password setting and security policy',
                icon: Icons.lock_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field(
                      controller: _passwordController,
                      label: _isEdit
                          ? 'New Password (Optional)'
                          : 'Initial Account Password',
                      icon: Icons.lock_outline,
                      required: !_isEdit,
                      obscureText: true,
                      suffixIcon: IconButton(
                        tooltip: _isPasswordVisible
                            ? 'Hide password'
                            : 'Show password',
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppInfoCard(
                      icon: Icons.info_outline,
                      label: _isEdit ? 'Password Update' : 'Password Policy',
                      value: _isEdit
                          ? 'Leave blank to keep current password. If changed, must be at least 8 characters with letters and numbers.'
                          : 'Must be at least 8 characters with letters and numbers. Share this temporary password securely.',
                    ),
                    if (_isEdit && isSuperAdmin) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Quick PIN Login Enabled'),
                        subtitle: const Text(
                          'Allow or disallow PIN authentication for this account',
                        ),
                        value: _pinEnabled,
                        onChanged: (val) {
                          setState(() {
                            _pinEnabled = val;
                            _isDirty = true;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _pinController,
                        label: 'Reset 4-Digit PIN (Optional)',
                        icon: Icons.pin_outlined,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        helperText:
                            'Leave blank to retain current PIN or enter 4 digits to set a new PIN.',
                      ),
                    ] else if (_isEdit) ...[
                      const SizedBox(height: 12),
                      AppInfoCard(
                        icon: Icons.pin_outlined,
                        label: 'PIN Login Status',
                        value: widget.existingUser!.pinEnabled
                            ? 'Quick PIN login is currently enabled for this account.'
                            : 'PIN login is not yet configured by the user.',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          AppDialogAction(
            label: 'Cancel',
            onPressed: _isSaving ? null : _handleCancel,
          ),
          AppDialogAction(
            label: _isSaving
                ? (_isEdit ? 'Saving...' : 'Creating...')
                : (_isEdit
                      ? 'Save Changes'
                      : (_role == UserRole.admin
                            ? 'Create Admin'
                            : (_role == UserRole.superAdmin
                                  ? 'Create Super Admin'
                                  : 'Create User'))),
            isPrimary: true,
            icon: Icons.save_outlined,
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    bool enabled = true,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText && !_isPasswordVisible,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        helperText: helperText,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (required && trimmed.isEmpty) return '$label is required.';
        if ((label == 'First Name' || label == 'Last Name') &&
            trimmed.isNotEmpty &&
            !isValidPersonName(trimmed)) {
          return 'Enter a valid name (2-50 letters).';
        }
        if (label == 'Email Address' && trimmed.isNotEmpty) {
          if (!isValidEmailAddress(trimmed)) {
            return 'Enter a valid email address (e.g. user@rhu.gov.ph).';
          }
        }
        if (label.contains('PIN') && trimmed.isNotEmpty) {
          if (!RegExp(r'^\d{4}$').hasMatch(trimmed)) {
            return 'PIN must be exactly 4 digits.';
          }
        }
        if (label.contains('Password') && trimmed.isNotEmpty) {
          if (trimmed.length < 8) {
            return 'Password must be at least 8 characters long.';
          }
          if (!RegExp(r'[A-Za-z]').hasMatch(trimmed) ||
              !RegExp(r'[0-9]').hasMatch(trimmed)) {
            return 'Password must include both letters and numbers.';
          }
        }
        if (label == 'Contact Number' && trimmed.isNotEmpty) {
          if (!isValidPhilippinePhone(trimmed)) {
            return 'Enter a valid Philippine mobile number (e.g. 0917-123-4567).';
          }
        }
        return null;
      },
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final curUser = ref.read(currentUserProvider);
    final isSuperAdmin = curUser?.isSuperAdmin == true;
    final targetClinicId = isSuperAdmin
        ? (_role == UserRole.superAdmin ? null : _clinicId)
        : curUser?.clinicId;

    if (_role != UserRole.superAdmin &&
        (targetClinicId == null || targetClinicId.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select an RHU facility for this ${_role.name} account in Role & Facility Assignment.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final currentUserId = curUser?.id ?? 'system';
    final repository = ref.read(authRepositoryProvider);

    try {
      if (_isEdit) {
        final user = widget.existingUser!;
        await repository.updateUser(
          id: user.id,
          email: isSuperAdmin
              ? _emailController.text.trim().toLowerCase()
              : null,
          clinicId: targetClinicId,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          contactNumber: _phoneOrNull(_contactController.text),
          licenseNumber: _emptyToNull(_licenseController.text),
          specialization: _emptyToNull(_specializationController.text),
          role: _role,
          isActive: _isActive,
          profileImageUrl: _profileImageUrl,
          newPassword: _emptyToNull(_passwordController.text),
          newPin: _emptyToNull(_pinController.text),
          pinEnabled: isSuperAdmin ? _pinEnabled : null,
          updatedByUserId: currentUserId,
        );
      } else {
        await repository.createUser(
          email: _emailController.text.trim().toLowerCase(),
          password: _passwordController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          role: _role,
          clinicId: targetClinicId,
          licenseNumber: _emptyToNull(_licenseController.text),
          specialization: _emptyToNull(_specializationController.text),
          contactNumber: _phoneOrNull(_contactController.text),
          profileImageUrl: _profileImageUrl,
          createdByUserId: currentUserId,
        );
      }

      ref.invalidate(usersProvider);
      if (mounted) {
        Navigator.pop(context, true);
        final roleLabel = _role == UserRole.admin
            ? 'Administrator'
            : (_role == UserRole.superAdmin
                  ? 'Super Administrator'
                  : 'Staff member');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit
                  ? '$roleLabel updated successfully'
                  : '$roleLabel created successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (e is ArgumentError) {
          msg = e.message.toString();
        } else if (e is StateError) {
          msg = e.message;
        } else {
          msg = msg.replaceFirst(
            RegExp(r'^[A-Za-z]+Exception:\s*|^[A-Za-z]+Error:\s*'),
            '',
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save user: $msg'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _phoneOrNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return isValidPhilippinePhone(trimmed)
        ? formatPhilippinePhone(trimmed)
        : trimmed;
  }
}
