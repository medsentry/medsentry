import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers/providers.dart';
import '../widgets/app_form_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Center(child: Text('No user logged in'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Text('My Profile', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(user.displayName),
            subtitle: Text(user.email),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text('Role'),
            subtitle: Text(user.roleDisplay),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(user.email),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Edit Profile'),
            onPressed: () => _editProfile(context, user),
          ),
        ],
      ),
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
