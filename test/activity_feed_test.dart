import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/audit_log.dart';
import 'package:medsentry/src/providers/activity_feed_provider.dart';
import 'package:medsentry/src/utils/date_time_format.dart';

AuditLog _log(String userId, DateTime at, {AuditAction? action}) => AuditLog(
  id: '$userId-${at.toIso8601String()}',
  userId: userId,
  action: action ?? AuditAction.create,
  entityType: AuditEntityTypes.patient,
  timestamp: at,
);

void main() {
  final seen = DateTime(2026, 10, 22, 9);

  test('only other people\'s actions after the last look are unread', () {
    final logs = [
      _log('maria', seen.add(const Duration(minutes: 5))),
      _log('me', seen.add(const Duration(minutes: 6))),
      _log('maria', seen.subtract(const Duration(minutes: 1))),
      _log('jose', seen.add(const Duration(hours: 1))),
    ];

    expect(countUnreadActivity(logs, seenAt: seen, userId: 'me'), 2);
  });

  test('nothing is unread until the last-seen time has loaded', () {
    final logs = [_log('maria', seen.add(const Duration(minutes: 5)))];

    expect(countUnreadActivity(logs, seenAt: null, userId: 'me'), 0);
  });

  test('record views and sync runs are left out of the feed', () {
    expect(isTeamActivity(_log('a', seen, action: AuditAction.read)), isFalse);
    expect(isTeamActivity(_log('a', seen, action: AuditAction.sync)), isFalse);
    expect(isTeamActivity(_log('a', seen, action: AuditAction.delete)), isTrue);
    expect(isTeamActivity(_log('a', seen, action: AuditAction.login)), isTrue);
  });

  test('relative times read naturally', () {
    final now = DateTime(2026, 10, 22, 21, 0);

    expect(formatRelativeTime(now, now: now), 'Just now');
    expect(
      formatRelativeTime(now.subtract(const Duration(minutes: 5)), now: now),
      '5 min ago',
    );
    expect(
      formatRelativeTime(now.subtract(const Duration(hours: 3)), now: now),
      '3 hr ago',
    );
    expect(
      formatRelativeTime(DateTime(2026, 10, 20, 9, 13), now: now),
      'Oct 20, 9:13 AM',
    );
  });
}
