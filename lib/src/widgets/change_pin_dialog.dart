import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import 'app_form_dialog.dart';

void showChangePinDialog(BuildContext context, WidgetRef ref) {
  final user = ref.read(currentUserProvider);
  final hasExistingPin = (user?.pinEnabled == true) &&
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
              bool isCurrentPinValid;
              try {
                isCurrentPinValid = await ref
                    .read(authRepositoryProvider)
                    .verifyPin(user.id, currentPin);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not verify PIN: $error')),
                  );
                }
                return;
              }
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

            try {
              await ref
                  .read(authRepositoryProvider)
                  .setupPin(user.id, newPin);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not save PIN online: $error')),
                );
              }
              return;
            }
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
                  action: SnackBarAction(
                    label: 'Lock Now',
                    textColor: AppColors.primaryEmerald,
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
                ),
              );
            }
          },
        ),
      ],
    ),
  ).whenComplete(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentPinController.dispose();
      newPinController.dispose();
      confirmPinController.dispose();
    });
  });
}

