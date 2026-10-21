import 'dart:async';

/// Runs at most one operation at a time.
///
/// A Dart future cannot be cancelled: when waiting times out, the operation
/// keeps running. Clearing a "busy" flag at that point let the next trigger
/// start a second pass over the same rows. Calls made while an operation is
/// still running join it instead of starting another.
class SingleFlight<T> {
  Future<T>? _running;

  bool get isRunning => _running != null;

  Future<T> run(
    Future<T> Function() operation, {
    required Duration timeout,
    required T Function() onTimeout,
  }) {
    return (_running ?? _start(operation)).timeout(
      timeout,
      onTimeout: onTimeout,
    );
  }

  Future<T> _start(Future<T> Function() operation) {
    // A Completer keeps the result typed as T: an operation that only throws
    // returns Future<Never>, which rejects a T from onTimeout at runtime.
    final completer = Completer<T>();
    _running = completer.future;
    // The slot is freed before the result is delivered, so a caller that
    // awaits a pass and runs again starts a new one.
    Future<T>.sync(operation).then(
      (value) {
        _running = null;
        completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        _running = null;
        completer.completeError(error, stackTrace);
      },
    );
    return completer.future;
  }
}
