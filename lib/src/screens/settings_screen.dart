import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/user.dart';
import '../services/app_notification.dart';
import '../providers/providers.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';
import '../widgets/system_logo.dart';
import '../widgets/status_badge.dart';
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
      maxWidth: 1280,
      padding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          Text(
            'Settings & Administration',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage account security, backups, compliance, and system configuration.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          _buildAppearanceSection(context, ref),
          const Divider(),
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
              () => _showChangePinDialog(context, ref),
            ),
          ]),
          if (currentUser?.canManageSystemData == true) ...[
            const Divider(),
            _buildSection(context, 'System Settings', [
              _buildListTile(
                context,
                'Clinic / RHU Information',
                'Manage clinic name, address, contact, and patient ID format',
                Icons.local_hospital_outlined,
                () => _showSystemSettingsDialog(context, ref),
              ),
            ]),
          ],
          if (currentUser?.isSuperAdmin != true) ...[
            const Divider(),
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
          const Divider(),
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
          const Divider(),
          settingsAsync.when(
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
                color: context.semanticColors.criticalBg.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _buildSection(context, 'Appearance & Theme', [
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme Mode',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select your preferred display mode or match your operating system.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined, size: 18),
                    label: Text('Light'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined, size: 18),
                    label: Text('Dark'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_brightness_outlined, size: 18),
                    label: Text('System'),
                  ),
                ],
                selected: {currentThemeMode},
                onSelectionChanged: (newSelection) {
                  ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(newSelection.first);
                },
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 14),
              Text(
                'Clinical Accent Theme',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose an accent palette for navigation, buttons, and active indicators.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppAccentTheme.values.map((accent) {
                  final isSelected = accent == currentAccentTheme;
                  return InkWell(
                    onTap: () {
                      ref
                          .read(accentThemeProvider.notifier)
                          .setAccentTheme(accent);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 108,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent.primaryColor.withValues(alpha: 0.12)
                            : colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? accent.primaryColor
                              : colorScheme.outlineVariant.withValues(
                                  alpha: 0.7,
                                ),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: accent.primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accent.primaryColor.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
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
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? accent.primaryColor
                                  : colorScheme.onSurface,
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
      ),
    ]);
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...children,
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
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      enabled: onTap != null,
      onTap: onTap,
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.semanticColors.neutral),
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    final hasExistingPin =
        (user?.pinEnabled == true) &&
        (user?.pinHash != null && user!.pinHash!.isNotEmpty);
    final isPinSetup = !hasExistingPin;
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AppFormDialog(
        icon: Icons.pin_outlined,
        title: isPinSetup ? 'Setup PIN' : 'Change PIN',
        subtitle: isPinSetup
            ? 'Setup a 4-digit access PIN for quick and secure login'
            : 'Update your 4-digit access PIN for secure login',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPinSetup) ...[
              AppFormField(
                label: 'Current PIN',
                hint: 'Enter your existing 4-digit PIN',
                field: TextField(
                  controller: currentPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                required: true,
              ),
              const SizedBox(height: 16),
            ],
            AppFormField(
              label: isPinSetup ? 'Create 4-Digit PIN' : 'New PIN',
              hint: isPinSetup ? 'Enter 4 digits' : 'Create a new 4-digit PIN',
              field: TextField(
                controller: newPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              required: true,
            ),
            const SizedBox(height: 16),
            AppFormField(
              label: 'Confirm PIN',
              hint: 'Re-enter your 4-digit PIN to confirm',
              field: TextField(
                controller: confirmPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              required: true,
            ),
          ],
        ),
        actions: [
          AppDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          AppDialogAction(
            label: isPinSetup ? 'Setup PIN' : 'Update PIN',
            isPrimary: true,
            icon: Icons.check,
            onPressed: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;

              final currentPin = currentPinController.text.trim();
              final newPin = newPinController.text.trim();
              final confirmPin = confirmPinController.text.trim();
              final pinRegex = RegExp(r'^\d{4}$');

              if (hasExistingPin) {
                final isCurrentPinValid = await ref
                    .read(authRepositoryProvider)
                    .verifyPin(user.id, currentPin);
                if (!isCurrentPinValid) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Current PIN is incorrect')),
                    );
                  }
                  return;
                }
              }

              if (!context.mounted) return;

              if (!pinRegex.hasMatch(newPin)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be exactly 4 digits')),
                );
                return;
              }

              if (newPin != confirmPin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PINs do not match')),
                );
                return;
              }

              await ref.read(authRepositoryProvider).setupPin(user.id, newPin);
              final refreshedUser = await ref
                  .read(authRepositoryProvider)
                  .getUserById(user.id);
              if (refreshedUser != null) {
                ref.read(currentUserProvider.notifier).state = refreshedUser;
              } else {
                ref.read(currentUserProvider.notifier).state = user.copyWith(
                  pinEnabled: true,
                  pinHash: 'configured',
                );
              }

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isPinSetup
                          ? 'PIN setup successfully'
                          : 'PIN updated successfully',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    ).whenComplete(() {
      currentPinController.dispose();
      newPinController.dispose();
      confirmPinController.dispose();
    });
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
                  'Patients, users, documents metadata, audit logs, and generated reports.',
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
              );
              final path = result?.files.single.path;
              if (path == null) return;

              if (!context.mounted) return;
              final confirmed = await _confirmRestore(context);
              if (!confirmed) return;

              try {
                await ref.read(databaseProvider).restoreFromBackup(path);
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
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'Restoring this backup will replace the current local data. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.restore_outlined),
            label: const Text('Restore'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _refreshAllProviders(WidgetRef ref) {
    ref.invalidate(settingsDataProvider);
    ref.invalidate(usersProvider);
    ref.invalidate(patientsProvider);
    ref.invalidate(documentsProvider);
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
    final settingsAsync = ref.read(settingsDataProvider);

    settingsAsync.when(
      data: (settings) {
        showDialog(
          context: context,
          builder: (context) => AppFormDialog(
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
        );
      },
      loading: () => _showSettingsLoadFeedback(
        context,
        message: 'System statistics are still loading. Try again shortly.',
      ),
      error: (error, _) {
        debugPrint('Failed to load system statistics: $error');
        _showSettingsLoadFeedback(
          context,
          message: 'System statistics could not be loaded.',
          onRetry: () => _showStatisticsDialog(context, ref),
        );
      },
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

  void _showSystemSettingsDialog(BuildContext context, WidgetRef ref) {
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
        var logoDataUri = settings.logoDataUri;

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
            if (file.size > 1024 * 1024) {
              throw const FormatException('Choose an image smaller than 1 MB.');
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
            debugPrint('Could not select clinic logo: $error\n$stackTrace');
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
              icon: Icons.local_hospital_outlined,
              title: 'Clinic Configuration',
              subtitle: 'Adapt MedSentry to this clinic without changing code',
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
                          'Organization Profile',
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        label: 'Clinic Name',
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
                              label: 'Organization Type',
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
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'System Logo',
                          style: Theme.of(ctx).textTheme.titleSmall,
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
                                const Text('Shown in the app header and login'),
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
                                        child: const Text('Remove'),
                                      ),
                                  ],
                                ),
                                Text(
                                  'PNG, JPG, or WebP; maximum 1 MB.',
                                  style: Theme.of(ctx).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        label: 'Address',
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
                        label: 'Contact Number',
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
                          'Enabled Modules',
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
                  label: 'Save',
                  isPrimary: true,
                  onPressed: () async {
                    await ref
                        .read(databaseProvider)
                        .updateSystemSettings(
                          settings.copyWith(
                            clinicName: clinicNameController.text.trim(),
                            clinicType: clinicTypeController.text.trim(),
                            clinicCode: clinicCodeController.text.trim(),
                            clinicAddress: clinicAddressController.text.trim(),
                            clinicContact: clinicContactController.text.trim(),
                            municipality: municipalityController.text.trim(),
                            province: provinceController.text.trim(),
                            operatingHours: operatingHoursController.text
                                .trim(),
                            patientIdPrefix: idPrefixController.text.trim(),
                            serviceTypes: _commaSeparatedValues(
                              servicesController.text,
                            ),
                            patientCategories: _commaSeparatedValues(
                              categoriesController.text,
                            ),
                            certificatesModuleEnabled: certificatesEnabled,
                            syncModuleEnabled: syncEnabled,
                            logoDataUri: logoDataUri,
                          ),
                        );
                    ref.invalidate(systemSettingsProvider);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('System settings saved')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ).whenComplete(() {
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
      },
      loading: () => _showSettingsLoadFeedback(
        context,
        message: 'System settings are still loading. Try again shortly.',
      ),
      error: (error, _) {
        debugPrint('Failed to load clinic details: $error');
        _showSettingsLoadFeedback(
          context,
          message: 'Clinic details could not be loaded.',
          onRetry: () => _showSystemSettingsDialog(context, ref),
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
    ).whenComplete(confirmationController.dispose);
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
  final bool embedded;

  const StaffManagementPanel({
    super.key,
    required this.onAddUser,
    required this.onEditUser,
    required this.onDeactivateUser,
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final tabView = usersAsync.when(
      data: (users) {
        final query = _searchQuery.trim().toLowerCase();
        final phoneQuery = query.replaceAll(RegExp(r'\D'), '');
        final scopedUsers = users.where((u) {
          if (currentUser == null) return false;

          if (!currentUser.isSuperAdmin) {
            // Administrators only manage accounts within their assigned RHU clinic.
            // Super administrators must NEVER be displayed or managed in clinic staff views.
            if (u.role == UserRole.superAdmin) return false;
            if (currentUser.clinicId != null &&
                u.clinicId != currentUser.clinicId) {
              return false;
            }
          }
          if (query.isEmpty) return true;
          return u.fullName.toLowerCase().contains(query) ||
              u.email.toLowerCase().contains(query) ||
              u.roleDisplay.toLowerCase().contains(query) ||
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
            ),
            _StaffAccountsTab(
              users: scopedUsers.where((u) => !u.isActive).toList(),
              currentUser: currentUser,
              emptyMessage: 'No inactive accounts.',
              showAddButton: false,
              onAddUser: widget.onAddUser,
              onEditUser: widget.onEditUser,
              onDeactivateUser: widget.onDeactivateUser,
            ),
            const _RolesPermissionsTab(),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search users by name, email, phone, or role...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active Users'),
            Tab(text: 'Inactive'),
            Tab(text: 'Roles & Permissions'),
          ],
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

  const _StaffAccountsTab({
    required this.users,
    required this.currentUser,
    required this.emptyMessage,
    required this.showAddButton,
    required this.onAddUser,
    required this.onEditUser,
    required this.onDeactivateUser,
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
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add User'),
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
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RolesPermissionsTab extends StatelessWidget {
  const _RolesPermissionsTab();

  static const _permissions = [
    _PermissionRow('Manage system settings', admin: true),
    _PermissionRow('User account management', admin: true),
    _PermissionRow('View audit logs', admin: true),
    _PermissionRow('Archive management', admin: true),
    _PermissionRow('Backup & synchronization', admin: true),
    _PermissionRow('Access patient records', admin: true, staff: true),
    _PermissionRow('Register patients', staff: true),
    _PermissionRow('Manage documents', admin: true, staff: true),
    _PermissionRow('Generate certificates', staff: true),
    _PermissionRow('Generate reports', admin: true, staff: true),
    _PermissionRow('Record synchronization', admin: true, staff: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Role access matrix',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Admin controls system operations. Staff handles daily patient record activities.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2.8),
                1: FlexColumnWidth(0.8),
                2: FlexColumnWidth(0.8),
              },
              border: TableBorder.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                  children: const [
                    _RoleHeaderCell('Permission'),
                    _RoleHeaderCell('Admin'),
                    _RoleHeaderCell('Staff'),
                  ],
                ),
                ..._permissions.map(
                  (row) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          row.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      _RoleCheckCell(allowed: row.admin),
                      _RoleCheckCell(allowed: row.staff),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionRow {
  final String label;
  final bool admin;
  final bool staff;

  const _PermissionRow(this.label, {this.admin = false, this.staff = false});
}

class _RoleHeaderCell extends StatelessWidget {
  final String label;

  const _RoleHeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _RoleCheckCell extends StatelessWidget {
  final bool allowed;

  const _RoleCheckCell({required this.allowed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Icon(
        allowed ? Icons.check_circle : Icons.remove_circle_outline,
        size: 18,
        color: allowed
            ? context.semanticColors.normal
            : context.semanticColors.neutral,
      ),
    );
  }
}

class _UserManagementTile extends StatelessWidget {
  final User user;
  final User? currentUser;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  const _UserManagementTile({
    required this.user,
    required this.currentUser,
    required this.onEdit,
    required this.onDeactivate,
  });

  bool get canEdit {
    if (currentUser == null) return false;
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.12),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            user.initials,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            if (user.isActive)
              StatusBadge.active(text: 'Active')
            else
              StatusBadge.inactive(text: 'Inactive'),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                user.email,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  user.roleDisplay,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (user.id == currentUser?.id)
                StatusBadge.info(text: 'Current User'),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
              IconButton(
                tooltip: 'Edit user',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
            if (canDeactivate && user.isActive && onDeactivate != null)
              IconButton(
                tooltip: 'Deactivate user',
                icon: const Icon(Icons.person_off_outlined),
                onPressed: onDeactivate,
              ),
          ],
        ),
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
  final _stepFormKeys = List.generate(3, (_) => GlobalKey<FormState>());
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _specializationController = TextEditingController();
  final _licenseController = TextEditingController();
  UserRole _role = UserRole.staff;
  String? _clinicId;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _isPasswordVisible = false;
  int _currentStep = 0;

  bool get _isEdit => widget.existingUser != null;

  void _markDirty() {
    if (!_isDirty && mounted) {
      setState(() => _isDirty = true);
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
      _role = user.role;
      _clinicId = user.clinicId;
      _isActive = user.isActive;
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
        maxWidth: 680,
        onClose: _isSaving ? null : _handleCancel,
        isLoading: _isSaving,
        loadingText: _isEdit
            ? 'Saving user account...'
            : 'Creating user account...',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRegistrationStepper(),
            const SizedBox(height: 16),
            SizedBox(
              height: 360,
              child: IndexedStack(
                index: _currentStep,
                children: [
                  Form(
                    key: _stepFormKeys[0],
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _field(
                            controller: _emailController,
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                            enabled: !_isEdit,
                            required: true,
                            keyboardType: TextInputType.emailAddress,
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
                            enabled: !_isEdit,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Form(
                    key: _stepFormKeys[1],
                    child: SingleChildScrollView(
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
                              data: (clinics) =>
                                  DropdownButtonFormField<String?>(
                                    initialValue: _clinicId,
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
                                          child: Text(
                                            '${clinic.name} (${clinic.code})',
                                          ),
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
                          const SizedBox(height: 16),
                          Text(
                            'Role Permissions & Access Overview',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          _RoleSummaryCard(role: _role),
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
                  ),
                  Form(
                    key: _stepFormKeys[2],
                    child: SingleChildScrollView(
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
                            label: _isEdit
                                ? 'Password Update'
                                : 'Password Policy',
                            value: _isEdit
                                ? 'Leave blank to keep the current password. If changed, must be at least 8 characters with letters and numbers.'
                                : 'Must be at least 8 characters with letters and numbers. Share this temporary password securely.',
                          ),
                          if (_isEdit) ...[
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
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_currentStep > 0)
            AppDialogAction(
              label: 'Back',
              onPressed: _isSaving ? null : _previousStep,
            )
          else
            AppDialogAction(
              label: 'Cancel',
              onPressed: _isSaving ? null : _handleCancel,
            ),
          if (_currentStep < 2)
            AppDialogAction(
              label: 'Next',
              isPrimary: true,
              icon: Icons.arrow_forward,
              onPressed: _isSaving ? null : _nextStep,
            )
          else
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

  Widget _buildRegistrationStepper() {
    const titles = ['Profile', 'Role & Access', 'Security'];
    return Row(
      children: [
        for (var index = 0; index < titles.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: index <= _currentStep
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: index <= _currentStep
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  child: index < _currentStep
                      ? const Icon(Icons.check, size: 18)
                      : Text('${index + 1}'),
                ),
                const SizedBox(height: 4),
                Text(
                  titles[index],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: index == _currentStep
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (index < titles.length - 1)
            Expanded(
              child: Divider(
                color: index < _currentStep
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
              ),
            ),
        ],
      ],
    );
  }

  void _nextStep() {
    if (!(_stepFormKeys[_currentStep].currentState?.validate() ?? false)) {
      return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
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
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText && !_isPasswordVisible,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
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
    if (!(_stepFormKeys[2].currentState?.validate() ?? false)) return;

    final curUser = ref.read(currentUserProvider);
    final isSuperAdmin = curUser?.isSuperAdmin == true;
    final targetClinicId = isSuperAdmin
        ? (_role == UserRole.superAdmin ? null : _clinicId)
        : curUser?.clinicId;

    if (_role != UserRole.superAdmin &&
        (targetClinicId == null || targetClinicId.trim().isEmpty)) {
      setState(() => _currentStep = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select an RHU facility for this ${_role.name} account in Role & Access.',
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
          clinicId: targetClinicId,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          contactNumber: _phoneOrNull(_contactController.text),
          specialization: _emptyToNull(_specializationController.text),
          role: _role,
          isActive: _isActive,
          newPassword: _emptyToNull(_passwordController.text),
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

class _RoleSummaryCard extends StatelessWidget {
  final UserRole role;

  const _RoleSummaryCard({required this.role});

  @override
  Widget build(BuildContext context) {
    final summary = switch (role) {
      UserRole.superAdmin =>
        'Platform-wide control: manage all Rural Health Units, administrators, staff, and platform oversight.',
      UserRole.admin =>
        'Full system control: user accounts, audit logs, settings, backup, and oversight.',
      UserRole.staff =>
        'Daily RHU operations: patient registration, documents, certificates, and reports.',
    };

    return AppInfoCard(
      icon: Icons.badge_outlined,
      label: role.name.toUpperCase(),
      value: summary,
    );
  }
}
