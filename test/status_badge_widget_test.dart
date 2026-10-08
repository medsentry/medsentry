import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/document.dart';
import 'package:medsentry/src/providers/theme_provider.dart';
import 'package:medsentry/src/widgets/status_badge.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: buildMedSentryTheme(Brightness.light),
      darkTheme: buildMedSentryTheme(Brightness.dark),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('StatusBadge Widget Tests', () {
    testWidgets('renders active status badge correctly', (tester) async {
      await tester.pumpWidget(createTestWidget(StatusBadge.active(text: 'Active Patient')));
      expect(find.text('Active Patient'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('renders pending status badge correctly', (tester) async {
      await tester.pumpWidget(createTestWidget(StatusBadge.pending(text: 'In Review')));
      expect(find.text('In Review'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
    });

    testWidgets('renders fromDocumentStatus correctly', (tester) async {
      await tester.pumpWidget(createTestWidget(StatusBadge.fromDocumentStatus(DocumentStatus.verified)));
      expect(find.text('Verified'), findsOneWidget);
    });
  });
}
