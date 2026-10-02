import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/widgets/layout/responsive_layout.dart';
import 'package:medsentry/src/utils/context_extensions.dart';

void main() {
  group('ResponsiveBreakpoints Tests', () {
    test('Correct screen type classification for widths', () {
      expect(ResponsiveBreakpoints.getScreenType(360), ResponsiveScreenType.mobile);
      expect(ResponsiveBreakpoints.getScreenType(599), ResponsiveScreenType.mobile);
      expect(ResponsiveBreakpoints.getScreenType(600), ResponsiveScreenType.tablet);
      expect(ResponsiveBreakpoints.getScreenType(1023), ResponsiveScreenType.tablet);
      expect(ResponsiveBreakpoints.getScreenType(1024), ResponsiveScreenType.desktop);
      expect(ResponsiveBreakpoints.getScreenType(1599), ResponsiveScreenType.desktop);
      expect(ResponsiveBreakpoints.getScreenType(1600), ResponsiveScreenType.ultraWide);
      expect(ResponsiveBreakpoints.getScreenType(2560), ResponsiveScreenType.ultraWide);
    });

    test('Grid columns calculation adapts across screen types', () {
      expect(ResponsiveBreakpoints.getGridColumns(360), 1);
      expect(ResponsiveBreakpoints.getGridColumns(720), 2);
      expect(ResponsiveBreakpoints.getGridColumns(1200), 4);
      expect(ResponsiveBreakpoints.getGridColumns(1920), 4);
    });
  });

  group('ResponsiveLayout Widget & Viewport Tests', () {
    testWidgets('Renders mobile widget at narrow viewport (< 600px)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveLayout(
              mobile: const Text('Mobile Layout'),
              tablet: const Text('Tablet Layout'),
              desktop: const Text('Desktop Layout'),
            ),
          ),
        ),
      );

      expect(find.text('Mobile Layout'), findsOneWidget);
      expect(find.text('Tablet Layout'), findsNothing);
      expect(find.text('Desktop Layout'), findsNothing);
    });

    testWidgets('Renders tablet widget at medium viewport (600 - 1024px)', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveLayout(
              mobile: const Text('Mobile Layout'),
              tablet: const Text('Tablet Layout'),
              desktop: const Text('Desktop Layout'),
            ),
          ),
        ),
      );

      expect(find.text('Tablet Layout'), findsOneWidget);
      expect(find.text('Mobile Layout'), findsNothing);
      expect(find.text('Desktop Layout'), findsNothing);
    });

    testWidgets('Renders desktop widget at wide viewport (> 1024px)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveLayout(
              mobile: const Text('Mobile Layout'),
              tablet: const Text('Tablet Layout'),
              desktop: const Text('Desktop Layout'),
            ),
          ),
        ),
      );

      expect(find.text('Desktop Layout'), findsOneWidget);
      expect(find.text('Mobile Layout'), findsNothing);
      expect(find.text('Tablet Layout'), findsNothing);
    });

    testWidgets('ResponsiveContentContainer constrains maxWidth on ultra-wide screens', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContentContainer(
              maxWidth: 1600,
              child: SizedBox(height: 100, child: Text('Constrained Content')),
            ),
          ),
        ),
      );

      expect(find.text('Constrained Content'), findsOneWidget);
      final constrainedBox = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(ResponsiveContentContainer),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(constrainedBox.constraints.maxWidth, 1600);
    });

    testWidgets('AdaptiveInteractiveTarget enforces 48x48 min touch targets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveInteractiveTarget(
              child: Container(width: 20, height: 20, color: Colors.blue),
            ),
          ),
        ),
      );

      final renderBox = tester.renderObject<RenderBox>(find.byType(AdaptiveInteractiveTarget));
      expect(renderBox.size.width >= 48.0, isTrue);
      expect(renderBox.size.height >= 48.0, isTrue);
    });

    testWidgets('Context extensions provide correct boolean getters', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late bool isMobile;
      late bool isTablet;
      late bool isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isMobile = context.isMobile;
              isTablet = context.isTablet;
              isDesktop = context.isDesktop;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(isMobile, isTrue);
      expect(isTablet, isFalse);
      expect(isDesktop, isFalse);
    });

    testWidgets('ResponsiveBreakpoints static helpers evaluate context correctly', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late bool isMobile;
      late bool isTablet;
      late bool isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isMobile = ResponsiveBreakpoints.isMobile(context);
              isTablet = ResponsiveBreakpoints.isTablet(context);
              isDesktop = ResponsiveBreakpoints.isDesktop(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(isMobile, isTrue);
      expect(isTablet, isFalse);
      expect(isDesktop, isFalse);
    });
  });
}
