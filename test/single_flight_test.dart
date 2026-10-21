import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/utils/single_flight.dart';

void main() {
  test('a call after a timeout joins the pass that is still running', () async {
    final flight = SingleFlight<String>();
    final slowPass = Completer<String>();
    var started = 0;

    Future<String> operation() {
      started++;
      return slowPass.future;
    }

    final first = await flight.run(
      operation,
      timeout: const Duration(milliseconds: 10),
      onTimeout: () => 'timed out',
    );
    expect(first, 'timed out');
    expect(flight.isRunning, isTrue);

    final second = flight.run(
      operation,
      timeout: const Duration(seconds: 5),
      onTimeout: () => 'timed out',
    );
    slowPass.complete('done');

    expect(await second, 'done');
    expect(started, 1);
  });

  test('a new pass starts once the previous one has finished', () async {
    final flight = SingleFlight<int>();
    var started = 0;

    for (var i = 0; i < 2; i++) {
      await flight.run(
        () async => ++started,
        timeout: const Duration(seconds: 5),
        onTimeout: () => -1,
      );
    }

    expect(started, 2);
    expect(flight.isRunning, isFalse);
  });

  test('a pass that fails releases the slot', () async {
    final flight = SingleFlight<int>();

    await expectLater(
      flight.run(
        () async => throw StateError('network'),
        timeout: const Duration(seconds: 5),
        onTimeout: () => -1,
      ),
      throwsStateError,
    );

    expect(flight.isRunning, isFalse);
    expect(
      await flight.run(
        () async => 7,
        timeout: const Duration(seconds: 5),
        onTimeout: () => -1,
      ),
      7,
    );
  });
}
