import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'providers.dart';

/// How many recent actions the notification bell lists.
const activityFeedLimit = 50;

/// Whether an audit entry is an action worth showing in the bell. Record
/// views and background sync runs are too frequent to be useful there.
bool isTeamActivity(AuditLog log) =>
    log.action != AuditAction.read && log.action != AuditAction.sync;

/// Actions by other people that happened after [seenAt]. The viewer's own
/// actions never count as unread.
int countUnreadActivity(
  Iterable<AuditLog> logs, {
  required DateTime? seenAt,
  required String userId,
}) {
  if (seenAt == null) return 0;
  return logs
      .where((log) => log.userId != userId && log.timestamp.isAfter(seenAt))
      .length;
}

/// Recent team actions, newest first, for the notification bell.
///
/// Built from the audit log. The server shares other people's entries only
/// with Admins (their own RHU) and Super Admins (every RHU), so Staff see the
/// actions taken on their own device.
final activityFeedProvider = FutureProvider<List<AuditLog>>((ref) async {
  ref.watch(databaseChangesProvider);
  final clinicId = ref.watch(activeClinicIdProvider);
  final logs = await ref
      .watch(databaseProvider)
      .getRecentAuditLogs(activityFeedLimit * 4, clinicId: clinicId);
  return logs.where(isTeamActivity).take(activityFeedLimit).toList();
});

/// When the user last opened the activity list, per user and device.
class ActivitySeenNotifier extends StateNotifier<DateTime?> {
  ActivitySeenNotifier(this._userId) : super(null) {
    _load();
  }

  final String _userId;

  String get _key => 'medsentry.activity_seen.$_userId';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = DateTime.tryParse(prefs.getString(_key) ?? '');
      if (saved != null) {
        state = saved;
      } else {
        // First run: start from now instead of flagging all past history.
        await markSeen();
      }
    } catch (_) {
      state = DateTime.now();
    }
  }

  Future<void> markSeen() async {
    final now = DateTime.now();
    state = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, now.toIso8601String());
    } catch (_) {}
  }
}

final activitySeenProvider =
    StateNotifierProvider.family<ActivitySeenNotifier, DateTime?, String>(
      (ref, userId) => ActivitySeenNotifier(userId),
    );

/// Number of unseen team actions for [userId], shown on the bell badge.
final activityUnreadCountProvider = Provider.family<int, String>((
  ref,
  userId,
) {
  final logs = ref.watch(activityFeedProvider).valueOrNull ?? const [];
  return countUnreadActivity(
    logs,
    seenAt: ref.watch(activitySeenProvider(userId)),
    userId: userId,
  );
});
