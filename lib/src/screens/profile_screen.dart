import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers/providers.dart';

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
            onPressed: () => _editProfile(context, ref, user),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(
    BuildContext pageContext,
    WidgetRef ref,
    User user,
  ) async {
    final firstName = TextEditingController(text: user.firstName);
    final lastName = TextEditingController(text: user.lastName);
    final contact = TextEditingController(text: user.contactNumber ?? '');
    final specialization = TextEditingController(text: user.specialization ?? '');
    var saving = false;

    try {
      await showDialog<void>(
        context: pageContext,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Edit profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: firstName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'First name'),
                  ),
                  TextField(
                    controller: lastName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Last name'),
                  ),
                  TextField(
                    controller: contact,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Contact number'),
                  ),
                  TextField(
                    controller: specialization,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Specialization'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          final updated = await ref
                              .read(authRepositoryProvider)
                              .updateUser(
                                id: user.id,
                                firstName: firstName.text.trim(),
                                lastName: lastName.text.trim(),
                                contactNumber: _emptyToNull(contact.text),
                                specialization: _emptyToNull(specialization.text),
                                updatedByUserId: user.id,
                              );
                          ref.read(currentUserProvider.notifier).state = updated;
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          if (pageContext.mounted) {
                            ScaffoldMessenger.of(pageContext).showSnackBar(
                              const SnackBar(content: Text('Profile updated')),
                            );
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text('Could not update profile: $error')),
                            );
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      firstName.dispose();
      lastName.dispose();
      contact.dispose();
      specialization.dispose();
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
