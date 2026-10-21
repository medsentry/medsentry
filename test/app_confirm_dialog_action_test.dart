import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/providers/theme_provider.dart';
import 'package:medsentry/src/widgets/app_confirm_dialog.dart';

void main() {
  late Completer<void> run;
  late int calls;
  late bool? result;

  Future<void> open(WidgetTester tester) async {
    calls = 0;
    result = null;
    run = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMedSentryTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await AppConfirmDialog.show(
                  context,
                  title: 'Delete Document',
                  message: 'This cannot be undone.',
                  confirmLabel: 'Delete',
                  busyLabel: 'Deleting…',
                  doneLabel: 'Deleted',
                  isDestructive: true,
                  action: () {
                    calls++;
                    return run.future;
                  },
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a double tap runs the action once and locks Cancel', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(find.text('Deleting…'), findsOneWidget);

    await tester.tap(find.text('Deleting…'));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Delete Document'), findsOneWidget);

    run.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Deleted'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Delete Document'), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('a failure stays in the dialog and can be retried', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    run.completeError(StateError('The file is open in another program.'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Document'), findsOneWidget);
    expect(find.text('The file is open in another program.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    run = Completer<void>()..complete();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(calls, 2);
    expect(find.text('Delete Document'), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('without an action the dialog only reports the choice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await AppConfirmDialog.show(
                  context,
                  title: 'Archive Patient',
                  message: 'It can be restored later.',
                  confirmLabel: 'Archive',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Archive Patient'), findsNothing);
    expect(result, isTrue);
  });
}
