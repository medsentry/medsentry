import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/app_notification.dart';
import '../providers/providers.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/screen_kit.dart';
import 'settings_screen.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The title, search, filters and tabs scroll away with the account list.
    return ResponsiveContentContainer(
      child: StaffManagementPanel(
        embedded: true,
        scrollsAsPage: true,
        leading: const [
          ScreenHeader(
            icon: Icons.badge_outlined,
            title: 'Staff',
            subtitle:
                'Administrators and staff accounts, their roles and RHU assignments.',
          ),
          SizedBox(height: 12),
        ],
        onAddUser: () => StaffActions.showForm(context, ref),
        onEditUser: (user) =>
            StaffActions.showForm(context, ref, existingUser: user),
        onDeactivateUser: (user) =>
            StaffActions.confirmDeactivate(context, ref, user),
        onDeleteUser: (user) => StaffActions.confirmDelete(context, ref, user),
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

    // The server call can fail offline; the dialog runs it and shows why.
    final deactivated = await AppConfirmDialog.show(
      context,
      title: 'Deactivate User',
      message:
          'Deactivate ${user.fullName}? They will no longer be able to sign in.',
      confirmLabel: 'Deactivate',
      busyLabel: 'Deactivating…',
      doneLabel: 'Deactivated',
      cancelLabel: 'Cancel',
      type: ConfirmDialogType.warning,
      isDestructive: true,
      icon: Icons.person_off_outlined,
      action: () => ref
          .read(authRepositoryProvider)
          .deactivateUser(user.id, currentUser?.id ?? 'system'),
    );
    if (!deactivated) return;

    ref.invalidate(usersProvider);
    AppNotification.success(
      title: 'User deactivated',
      message: '${user.fullName} can no longer sign in.',
    );
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

    final deleted = await AppConfirmDialog.show(
      context,
      title: 'Delete User Permanently',
      message:
          'Permanently delete ${user.fullName} (${user.email})? This cannot be undone. Existing clinical records and audit history will be retained.',
      confirmLabel: 'Delete permanently',
      busyLabel: 'Deleting…',
      doneLabel: 'Deleted',
      cancelLabel: 'Cancel',
      type: ConfirmDialogType.warning,
      isDestructive: true,
      icon: Icons.delete_forever_outlined,
      action: () => ref
          .read(authRepositoryProvider)
          .deleteUser(user.id, currentUser.id),
    );
    if (!deleted) return;

    ref.invalidate(usersProvider);
    AppNotification.success(
      title: 'User deleted',
      message: '${user.fullName} was permanently deleted.',
    );
  }
}
