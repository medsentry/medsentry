import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medsentry/src/navigation/navigation_memory.dart';

/// A two-tab screen like the app's: remembered tabs, kept alive.
class _TabbedPage extends StatelessWidget {
  const _TabbedPage();

  static const memory = TabMemory('demo', ['notes', 'history']);

  @override
  Widget build(BuildContext context) {
    return RememberedTabs(
      memory: memory,
      builder: (context, controller) => Column(
        children: [
          TabBar(
            controller: controller,
            tabs: const [Tab(text: 'Notes'), Tab(text: 'History')],
          ),
          Expanded(
            child: TabBarView(
              controller: controller,
              children: const [
                KeepAliveTab(child: TextField(key: Key('note'))),
                KeepAliveTab(child: Text('history list')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

GoRouter _router(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(
        body: Column(
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: () => shell.goBranch(0),
                  child: const Text('go records'),
                ),
                TextButton(
                  onPressed: () => shell.goBranch(1),
                  child: const Text('go other'),
                ),
              ],
            ),
            Expanded(child: shell),
          ],
        ),
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/records',
              builder: (context, state) => const _TabbedPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/other',
              builder: (context, state) => const Text('other section'),
            ),
          ],
        ),
      ],
    ),
  ],
);

Future<GoRouter> _open(WidgetTester tester, String location) async {
  final router = _router(location);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  setUp(NavigationMemory.debugReset);

  testWidgets('switching tabs updates the address in place and is saved', (
    tester,
  ) async {
    final router = await _open(tester, '/records');

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('history list'), findsOneWidget);
    expect(_location(router), '/records?tab=history');
    expect(NavigationMemory.instance.tab('demo'), 'history');
  });

  testWidgets('text typed in a tab survives switching tabs', (tester) async {
    await _open(tester, '/records');

    await tester.enterText(find.byKey(const Key('note')), 'BP 120/80');
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();

    expect(find.text('BP 120/80'), findsOneWidget);
  });

  testWidgets('a restart reopens the tab used last', (tester) async {
    NavigationMemory.debugReset({'nav.tab.demo': 'history'});

    await _open(tester, '/records');

    expect(find.text('history list'), findsOneWidget);
  });

  testWidgets('a link with ?tab= wins over the saved tab', (tester) async {
    NavigationMemory.debugReset({'nav.tab.demo': 'history'});

    await _open(tester, '/records?tab=notes');

    expect(find.byKey(const Key('note')), findsOneWidget);
    expect(find.text('history list'), findsNothing);
  });

  testWidgets('leaving the section and coming back keeps tab and input', (
    tester,
  ) async {
    await _open(tester, '/records');
    await tester.enterText(find.byKey(const Key('note')), 'Follow up Monday');

    await tester.tap(find.text('go other'));
    await tester.pumpAndSettle();
    expect(find.text('other section'), findsOneWidget);

    await tester.tap(find.text('go records'));
    await tester.pumpAndSettle();
    expect(find.text('Follow up Monday'), findsOneWidget);
  });

  test('the sign-in page is never remembered as a place to return to', () {
    final memory = NavigationMemory.instance;

    memory.rememberLocation('u1', Uri.parse('/certificates?tab=registry'));
    memory.rememberLocation('u1', Uri.parse('/login?locked=1'));

    expect(memory.lastLocation('u1'), '/certificates?tab=registry');
    expect(memory.lastLocation('u2'), isNull);
  });
}
