import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/navigation/navigation_memory.dart';

/// Runs around every test file. The app remembers the open tab of each
/// screen; without a reset, the tab one test leaves open would be where the
/// next test's screen starts.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(NavigationMemory.debugReset);
  await testMain();
}
