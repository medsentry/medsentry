import 'dart:collection';

/// A sliding-window rate limiter designed to guard against brute-force attacks
/// and rapid repetitive operations (logins, PIN attempts, manual sync spam).
class RateLimiter {
  final int maxAttempts;
  final Duration window;
  final Map<String, Queue<DateTime>> _attempts = {};

  RateLimiter({
    required this.maxAttempts,
    required this.window,
  });

  /// Checks whether an action for [key] can proceed. If within limits, records
  /// the attempt and returns `true`. If rate limited, returns `false`.
  bool tryAcquire(String key) {
    _cleanExpired(key);
    final queue = _attempts.putIfAbsent(key, () => Queue<DateTime>());
    if (queue.length >= maxAttempts) {
      return false;
    }
    queue.addLast(DateTime.now());
    return true;
  }

  /// Checks if another attempt is currently allowed without recording it.
  bool canAttempt(String key) {
    _cleanExpired(key);
    final count = _attempts[key]?.length ?? 0;
    return count < maxAttempts;
  }

  /// Records an attempt for [key].
  void recordAttempt(String key) {
    _cleanExpired(key);
    final queue = _attempts.putIfAbsent(key, () => Queue<DateTime>());
    queue.addLast(DateTime.now());
  }

  /// Returns the cooldown duration remaining, or Duration.zero if not limited.
  Duration remainingCooldown(String key) {
    return timeUntilReset(key) ?? Duration.zero;
  }

  /// Returns the number of attempts remaining in the current sliding window.
  int remainingAttempts(String key) {
    _cleanExpired(key);
    final count = _attempts[key]?.length ?? 0;
    return (maxAttempts - count).clamp(0, maxAttempts);
  }

  /// Returns the duration until the earliest recorded attempt expires,
  /// or `null` if not currently rate limited.
  Duration? timeUntilReset(String key) {
    _cleanExpired(key);
    final queue = _attempts[key];
    if (queue == null || queue.length < maxAttempts) {
      return null;
    }
    final earliest = queue.first;
    final expiresAt = earliest.add(window);
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Clears recorded attempts for [key] upon a successful operation (e.g. valid login).
  void recordSuccess(String key) {
    _attempts.remove(key);
  }

  /// Explicitly reset rate limit history for [key].
  void reset(String key) {
    _attempts.remove(key);
  }

  void _cleanExpired(String key) {
    final queue = _attempts[key];
    if (queue == null) return;
    final cutoff = DateTime.now().subtract(window);
    while (queue.isNotEmpty && queue.first.isBefore(cutoff)) {
      queue.removeFirst();
    }
    if (queue.isEmpty) {
      _attempts.remove(key);
    }
  }
}

/// System-wide rate limiter for password login attempts (5 attempts per 15 minutes).
final loginRateLimiter = RateLimiter(
  maxAttempts: 5,
  window: const Duration(minutes: 15),
);

/// System-wide rate limiter for PIN unlock attempts (5 attempts per 5 minutes).
final pinRateLimiter = RateLimiter(
  maxAttempts: 5,
  window: const Duration(minutes: 5),
);

/// Rate limiter for manual sync button clicks (1 request per 10 seconds).
final manualSyncRateLimiter = RateLimiter(
  maxAttempts: 1,
  window: const Duration(seconds: 10),
);

/// Rate limiter for report PDF generation (1 export per 3 seconds).
final reportExportRateLimiter = RateLimiter(
  maxAttempts: 1,
  window: const Duration(seconds: 3),
);
