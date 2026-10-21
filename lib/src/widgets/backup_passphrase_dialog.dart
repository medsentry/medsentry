import 'package:flutter/material.dart';

import '../database/storage/store_cipher.dart';
import 'app_form_dialog.dart';

/// Asks for the passphrase that protects a database backup file.
///
/// When [confirm] is true (creating a backup) the passphrase is entered twice,
/// because a mistyped one would make the backup permanently unreadable.
/// Returns null when cancelled.
class BackupPassphraseDialog extends StatefulWidget {
  final bool confirm;

  const BackupPassphraseDialog({super.key, required this.confirm});

  static Future<String?> show(BuildContext context, {required bool confirm}) {
    return showDialog<String>(
      context: context,
      builder: (_) => BackupPassphraseDialog(confirm: confirm),
    );
  }

  @override
  State<BackupPassphraseDialog> createState() => _BackupPassphraseDialogState();
}

class _BackupPassphraseDialogState extends State<BackupPassphraseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passphrase = TextEditingController();
  final _repeat = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _passphrase.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(context, _passphrase.text);
  }

  @override
  Widget build(BuildContext context) {
    const minimum = BackupCipher.minimumPassphraseLength;
    return AppFormDialog(
      icon: Icons.key_outlined,
      title: widget.confirm ? 'Protect Backup' : 'Unlock Backup',
      subtitle: widget.confirm
          ? 'The backup file is encrypted with this passphrase'
          : 'Enter the passphrase used when this backup was created',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: _passphrase,
              label: 'Backup passphrase',
              icon: Icons.lock_outline,
              required: true,
              obscureText: !_visible,
              suffixIcon: IconButton(
                tooltip: _visible ? 'Hide passphrase' : 'Show passphrase',
                onPressed: () => setState(() => _visible = !_visible),
                icon: Icon(
                  _visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              validator: (value) => widget.confirm && (value ?? '').length < minimum
                  ? 'Use at least $minimum characters.'
                  : null,
            ),
            if (widget.confirm) ...[
              const SizedBox(height: 12),
              AppTextField(
                controller: _repeat,
                label: 'Repeat passphrase',
                icon: Icons.lock_outline,
                required: true,
                obscureText: !_visible,
                validator: (value) => value != _passphrase.text
                    ? 'The passphrases do not match.'
                    : null,
              ),
              const SizedBox(height: 16),
              const AppWarningCard(
                title: 'Keep this passphrase safe',
                message:
                    'Without it the backup cannot be restored. MedSentry '
                    'cannot recover a forgotten passphrase.',
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: widget.confirm ? 'Create Backup' : 'Unlock',
          isPrimary: true,
          icon: Icons.check,
          onPressed: _submit,
        ),
      ],
    );
  }
}
