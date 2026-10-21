import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/widgets/backup_passphrase_dialog.dart';

void main() {
  /// Opens the dialog and returns a getter for the value it closed with.
  Future<String? Function()> open(
    WidgetTester tester, {
    required bool confirm,
  }) async {
    tester.view.physicalSize = const Size(1400, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    String? returned;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              returned = await BackupPassphraseDialog.show(
                context,
                confirm: confirm,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => returned;
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('creating a backup needs a matching passphrase', (tester) async {
    await open(tester, confirm: true);

    await tester.enterText(field('Backup passphrase *'), 'clinic-2026');
    await tester.enterText(field('Repeat passphrase *'), 'clinic-2025');
    await tester.tap(find.text('Create Backup'));
    await tester.pumpAndSettle();
    expect(find.text('The passphrases do not match.'), findsOneWidget);
    expect(find.byType(BackupPassphraseDialog), findsOneWidget);

    await tester.enterText(field('Backup passphrase *'), 'short');
    await tester.enterText(field('Repeat passphrase *'), 'short');
    await tester.tap(find.text('Create Backup'));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(find.byType(BackupPassphraseDialog), findsOneWidget);
  });

  testWidgets('a valid passphrase closes the dialog with it', (tester) async {
    final returned = await open(tester, confirm: true);

    await tester.enterText(field('Backup passphrase *'), 'clinic-2026');
    await tester.enterText(field('Repeat passphrase *'), 'clinic-2026');
    await tester.tap(find.text('Create Backup'));
    await tester.pumpAndSettle();

    expect(find.byType(BackupPassphraseDialog), findsNothing);
    expect(returned(), 'clinic-2026');
  });

  testWidgets('unlocking asks for the passphrase once', (tester) async {
    final returned = await open(tester, confirm: false);

    expect(field('Repeat passphrase *'), findsNothing);
    await tester.enterText(field('Backup passphrase *'), 'any');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(returned(), 'any');
  });
}
