import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers/providers.dart';
import '../widgets/app_card.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/status_badge.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Center(child: Text('No user logged in'));
    }

    final theme = Theme.of(context);

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
                      'Personal credentials, contact details, and clinical specialization.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Profile'),
                onPressed: () => _editProfile(context, user),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // User Header Card
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        color: AppColors.primaryEmerald,
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                      ),
                    ),
                  ),
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
                          if (user.isActive)
                            StatusBadge.active(text: 'Active', showDot: true)
                          else
                            StatusBadge.inactive(text: 'Inactive', showDot: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.elevatedSurface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          user.roleDisplay,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.textSecondary,
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
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Role & Permissions',
                  value: user.roleDisplay,
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
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 14),
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
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

  bool _isSaving = false;
  bool _isDirty = false;

  void _markDirty() {
    if (!_isDirty && mounted) {
      setState(() => _isDirty = true);
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

    _firstNameController.addListener(_markDirty);
    _lastNameController.addListener(_markDirty);
    _contactController.addListener(_markDirty);
    _specializationController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactController.dispose();
    _specializationController.dispose();
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
            specialization: _specializationController.text.trim().isEmpty
                ? null
                : _specializationController.text.trim(),
            updatedByUserId: user.id,
          );
      ref.read(currentUserProvider.notifier).state = updated;

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
            'Update your personal name, contact details, and clinical specialization',
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
