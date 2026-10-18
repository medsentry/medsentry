import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers/providers.dart';
import '../widgets/app_card.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import 'settings_screen.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsiveContentContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Staff',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage administrators and staff accounts for this RHU.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AppCard(
              expandContent: true,
              padding: const EdgeInsets.all(16),
              child: StaffManagementPanel(
                embedded: true,
                onAddUser: () => _showStaffFormDialog(context, ref),
                onEditUser: (user) =>
                    _showStaffFormDialog(context, ref, existingUser: user),
                onDeactivateUser: (user) =>
                    _confirmDeactivateStaff(context, ref, user),
                onDeleteUser: (user) => _confirmDeleteStaff(context, ref, user),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStaffFormDialog(
    BuildContext context,
    WidgetRef ref, {
    User? existingUser,
  }) async {
    final currentUser = ref.read(currentUserProvider);
    if (existingUser?.role == UserRole.superAdmin &&
        currentUser?.isSuperAdmin != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Administrators cannot edit Super Administrator accounts.',
          ),
        ),
      );
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StaffFormDialog(existingUser: existingUser),
    );

    if (saved == true) {
      ref.invalidate(usersProvider);
      if (currentUser != null && currentUser.id == existingUser?.id) {
        final refreshed = await ref
            .read(authRepositoryProvider)
            .getUserById(currentUser.id);
        if (refreshed != null) {
          ref.read(currentUserProvider.notifier).state = refreshed;
        }
      }
    }
  }

  Future<void> _confirmDeactivateStaff(
    BuildContext context,
    WidgetRef ref,
    User user,
  ) async {
    final currentUser = ref.read(currentUserProvider);
    if (user.role == UserRole.superAdmin && currentUser?.isSuperAdmin != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Administrators cannot deactivate Super Administrator accounts.',
          ),
        ),
      );
      return;
    }
    if (currentUser?.id == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot deactivate your own account.'),
        ),
      );
      return;
    }

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Deactivate User',
      message:
          'Deactivate ${user.fullName}? They will no longer be able to sign in.',
      confirmLabel: 'Deactivate',
      cancelLabel: 'Cancel',
      type: ConfirmDialogType.warning,
      isDestructive: true,
      icon: Icons.person_off_outlined,
    );

    if (confirmed != true) return;

    await ref
        .read(authRepositoryProvider)
        .deactivateUser(user.id, currentUser?.id ?? 'system');
    ref.invalidate(usersProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${user.fullName} deactivated')));
    }
  }

  Future<void> _confirmDeleteStaff(
    BuildContext context,
    WidgetRef ref,
    User user,
  ) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || !currentUser.canManageStaffAccounts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not allowed to delete accounts.'),
        ),
      );
      return;
    }
    if (currentUser.id == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot delete your own account.')),
      );
      return;
    }
    if (!currentUser.isSuperAdmin &&
        (user.role == UserRole.superAdmin ||
            user.clinicId != currentUser.clinicId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not allowed to delete this account.'),
        ),
      );
      return;
    }

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Delete User Permanently',
      message:
          'Permanently delete ${user.fullName} (${user.email})? This cannot be undone. Existing clinical records and audit history will be retained.',
      confirmLabel: 'Delete permanently',
      cancelLabel: 'Cancel',
      type: ConfirmDialogType.warning,
      isDestructive: true,
      icon: Icons.delete_forever_outlined,
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(authRepositoryProvider)
          .deleteUser(user.id, currentUser.id);
      ref.invalidate(usersProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.fullName} permanently deleted')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete ${user.fullName}: $error')),
        );
      }
    }
  }
}
