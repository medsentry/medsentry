import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/providers.dart';
import '../services/document_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/change_pin_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/status_badge.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Center(child: Text('No user logged in'));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryTextColor = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;

    return ResponsiveContentContainer(
      maxWidth: 800,
      padding: ResponsiveLayout.pagePadding(context),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Profile',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Personal credentials, PRC license, contact details, and clinical specialization.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Lock Screen'),
                    onPressed: () async {
                      await ref
                          .read(authRepositoryProvider)
                          .lockSession(userId: user.id);
                      ref.read(currentUserProvider.notifier).state = null;
                      if (context.mounted) {
                        context.go('/login?locked=1');
                      }
                    },
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Profile'),
                    onPressed: () => _editProfile(context, user),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // User Header Card
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                UserAvatar(
                  user: user,
                  radius: 36,
                  showStatusIndicator: true,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.fullName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (user.isReactivated)
                            StatusBadge.info(text: 'Reactivated', showDot: true)
                          else if (user.isActive)
                            StatusBadge.active(text: 'Active', showDot: true)
                          else
                            StatusBadge.inactive(text: 'Inactive', showDot: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.elevatedSurface
                              : AppColors.lightElevatedSurface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark ? AppColors.border : AppColors.lightBorder,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          user.roleDisplay,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account Details Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _buildProfileDetailRow(
                  context,
                  icon: Icons.person_outline,
                  label: 'Full Name',
                  value: user.fullName,
                ),
                const Divider(height: 24),
                _buildProfileDetailRow(
                  context,
                  icon: Icons.email_outlined,
                  label: 'Email Address',
                  value: user.email,
                ),
                const Divider(height: 24),
                _buildProfileDetailRow(
                  context,
                  icon: Icons.phone_outlined,
                  label: 'Contact Number',
                  value: user.contactNumber ?? 'Not provided',
                ),
                const Divider(height: 24),
                _buildProfileDetailRow(
                  context,
                  icon: Icons.medical_services_outlined,
                  label: 'Specialization',
                  value: user.specialization ?? 'General Healthcare',
                ),
                const Divider(height: 24),
                _buildProfileDetailRow(
                  context,
                  icon: Icons.credit_card_outlined,
                  label: 'PRC License No.',
                  value: (user.licenseNumber != null &&
                          user.licenseNumber!.trim().isNotEmpty)
                      ? user.licenseNumber!
                      : 'Not provided',
                ),
                const Divider(height: 24),
                _buildProfileDetailRow(
                  context,
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Role & Permissions',
                  value: user.roleDisplay,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Security & Quick Lock Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Terminal Security & Quick Access',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (user.pinEnabled)
                      StatusBadge.active(text: 'PIN Enabled', showDot: true)
                    else
                      StatusBadge.inactive(text: 'No PIN Setup', showDot: false),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user.pinEnabled
                      ? 'Your account has a 4-digit PIN configured. You can lock your workstation screen anytime and resume work without retyping your password.'
                      : 'No 4-digit access PIN is currently configured for this account. Set up a PIN in Settings for fast, single-tap terminal unlock.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryEmerald,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: const Text('Lock Screen Now'),
                      onPressed: () async {
                        await ref
                            .read(authRepositoryProvider)
                            .lockSession(userId: user.id);
                        ref.read(currentUserProvider.notifier).state = null;
                        if (context.mounted) {
                          context.go('/login?locked=1');
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.pin_outlined, size: 18),
                      label: Text(user.pinEnabled ? 'Change PIN' : 'Setup PIN'),
                      onPressed: () => showChangePinDialog(context, ref),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Workstation Appearance & Theme Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workstation Display & Theme',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Personalize your terminal appearance, dark mode, and clinical accent colors.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),
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
                  selected: {ref.watch(themeModeProvider)},
                  onSelectionChanged: (newSelection) {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(newSelection.first);
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Clinical Accent Color',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppAccentTheme.values.map((accent) {
                    final currentAccentTheme = ref.watch(accentThemeProvider);
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
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? accent.primaryColor
                                : theme.colorScheme.outlineVariant.withValues(
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
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              accent.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
      ),
    );
  }

  Widget _buildProfileDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;
    return Row(
      children: [
        Icon(icon, size: 20, color: secondaryColor),
        const SizedBox(width: 14),
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: secondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editProfile(BuildContext pageContext, User user) async {
    await showDialog<void>(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogContext) => _EditProfileDialog(user: user),
    );
  }
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  final User user;

  const _EditProfileDialog({required this.user});

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _contactController;
  late final TextEditingController _specializationController;
  late final TextEditingController _licenseController;
  String? _profileImageUrl;

  bool _isSaving = false;
  bool _isDirty = false;

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
    final user = widget.user;
    _firstNameController = TextEditingController(text: user.firstName);
    _lastNameController = TextEditingController(text: user.lastName);
    _contactController = TextEditingController(text: user.contactNumber ?? '');
    _specializationController = TextEditingController(
      text: user.specialization ?? '',
    );
    _licenseController = TextEditingController(text: user.licenseNumber ?? '');
    _profileImageUrl = user.profileImageUrl;

    _firstNameController.addListener(_markDirty);
    _lastNameController.addListener(_markDirty);
    _contactController.addListener(_markDirty);
    _specializationController.addListener(_markDirty);
    _licenseController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactController.dispose();
    _specializationController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _handleCancel() async {
    if (!_isDirty || _isSaving) {
      Navigator.of(context).pop();
      return;
    }
    final shouldDiscard = await confirmDiscardUnsavedChanges(context);
    if (shouldDiscard && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final user = widget.user;
    final contactRaw = _contactController.text.trim();
    final normalizedContact = contactRaw.isEmpty
        ? null
        : (isValidPhilippinePhone(contactRaw)
            ? formatPhilippinePhone(contactRaw)
            : contactRaw);

    try {
      final updated = await ref.read(authRepositoryProvider).updateUser(
            id: user.id,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            contactNumber: normalizedContact,
            licenseNumber: _licenseController.text.trim().isEmpty
                ? null
                : _licenseController.text.trim(),
            specialization: _specializationController.text.trim().isEmpty
                ? null
                : _specializationController.text.trim(),
            profileImageUrl: _profileImageUrl,
            updatedByUserId: user.id,
          );
      ref.read(currentUserProvider.notifier).state = updated;
      ref.invalidate(usersProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update profile: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty || _isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleCancel();
      },
      child: AppFormDialog(
        icon: Icons.person_outline,
        title: 'Edit Profile',
        subtitle:
            'Update your personal name, contact details, PRC license, and clinical specialization',
        maxWidth: 520,
        isLoading: _isSaving,
        loadingText: 'Saving changes...',
        onClose: _isSaving ? null : _handleCancel,
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Stack(
                    children: [
                      UserAvatar(
                        user: widget.user.copyWith(
                          firstName: _firstNameController.text.isNotEmpty
                              ? _firstNameController.text
                              : widget.user.firstName,
                          lastName: _lastNameController.text.isNotEmpty
                              ? _lastNameController.text
                              : widget.user.lastName,
                          profileImageUrl: _profileImageUrl,
                        ),
                        radius: 40,
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
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      icon: Icons.person_outline,
                      required: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'First name is required.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      icon: Icons.person_outline,
                      required: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Last name is required.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppPhoneField(
                controller: _contactController,
                label: 'Mobile Contact Number',
                required: false,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _specializationController,
                label: 'Specialization / Role Description',
                hint: 'e.g. Municipal Health Officer, Registered Nurse',
                icon: Icons.medical_services_outlined,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _licenseController,
                label: 'Professional PRC License Number',
                hint: 'e.g. PRC-0123456',
                icon: Icons.credit_card_outlined,
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
            label: _isSaving ? 'Saving...' : 'Save Profile',
            isPrimary: true,
            icon: Icons.save_outlined,
            onPressed: _isSaving ? null : _handleSave,
          ),
        ],
      ),
    );
  }
}
