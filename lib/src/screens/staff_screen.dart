import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers/providers.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/screen_kit.dart';
import 'settings_screen.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ResponsiveContentContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenHeader(
            icon: Icons.badge_outlined,
            title: 'Staff',
            subtitle:
                'Administrators and staff accounts, their roles and RHU assignments.',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardSurface : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderSubtle
                      : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: StaffManagementPanel(
                embedded: true,
                onAddUser: () => StaffActions.showForm(context, ref),
                onEditUser: (user) =>
                    StaffActions.showForm(context, ref, existingUser: user),
                onDeactivateUser: (user) =>
                    StaffActions.confirmDeactivate(context, ref, user),
                onDeleteUser: (user) =>
                    StaffActions.confirmDelete(context, ref, user),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Add, edit, deactivate and delete for staff accounts, shared by the Staff
/// page and the facility page.
class StaffActions {
  const StaffActions._();

  /// [initialClinicId] pre-selects the RHU for a new account.
  static Future<void> showForm(
    BuildContext context,
    WidgetRef ref, {
    User? existingUser,
    String? initialClinicId,
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
      builder: (_) => StaffFormDialog(
        existingUser: existingUser,
        initialClinicId: initialClinicId,
      ),
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

  static Future<void> confirmDeactivate(
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

  static Future<void> confirmDelete(
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
