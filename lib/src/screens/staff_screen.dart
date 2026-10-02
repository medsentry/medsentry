import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers/providers.dart';
import '../widgets/layout/responsive_layout.dart';
import 'settings_screen.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsiveContentContainer(
      child: Padding(
        padding: ResponsiveLayout.pagePadding(context),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Users',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage administrators and staff accounts for this RHU.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: StaffManagementPanel(
                  embedded: true,
                  onAddUser: () => _showStaffFormDialog(context, ref),
                  onEditUser: (user) =>
                      _showStaffFormDialog(context, ref, existingUser: user),
                  onDeactivateUser: (user) =>
                      _confirmDeactivateStaff(context, ref, user),
                ),
              ),
            ),
          ),
        ],
      ),
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate User'),
        content: Text(
          'Deactivate ${user.fullName}? They will no longer be able to sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.person_off_outlined),
            label: const Text('Deactivate'),
          ),
        ],
      ),
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
}
