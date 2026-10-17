import '../database/simple_database.dart';
import '../models/models.dart';

class NotificationService {
  final SimpleDatabase _db;

  NotificationService(this._db);

  /// Scan system state and create alerts for admin/staff.
  Future<void> refreshSystemNotifications() async {
    await _db.deleteNotification('pending_docs');
    final pendingSync = await _db.getPendingSyncCount();
    final failedLogins = await _db.getFailedLoginCount(
      within: const Duration(days: 1),
    );

    if (pendingSync > 0) {
      await _upsertNotification(
        id: 'sync_pending',
        type: NotificationType.syncFailed,
        target: NotificationTarget.all,
        priority: NotificationPriority.high,
        title: 'Records Pending Sync',
        message:
            '$pendingSync record${pendingSync == 1 ? '' : 's'} waiting to synchronize with cloud storage.',
        actionRoute: '/sync',
      );
    } else {
      await _db.deleteNotification('sync_pending');
    }

    if (failedLogins > 0) {
      await _upsertNotification(
        id: 'failed_logins',
        type: NotificationType.suspiciousActivity,
        target: NotificationTarget.admin,
        priority: NotificationPriority.urgent,
        title: 'Failed Login Attempts',
        message:
            '$failedLogins failed login attempt${failedLogins == 1 ? '' : 's'} detected in the last 24 hours.',
        actionRoute: '/audit-logs',
      );
    } else {
      await _db.deleteNotification('failed_logins');
    }
  }

  Future<void> notifyIncompleteRecord(
    String patientId,
    String patientName,
  ) async {
    await _upsertNotification(
      id: 'incomplete_$patientId',
      type: NotificationType.incompleteRecord,
      target: NotificationTarget.staff,
      priority: NotificationPriority.normal,
      title: 'Incomplete Patient Record',
      message: 'Patient $patientName has missing required information.',
      actionRoute: '/patients/$patientId',
    );
  }

  Future<void> _upsertNotification({
    required String id,
    required NotificationType type,
    required NotificationTarget target,
    required NotificationPriority priority,
    required String title,
    required String message,
    String? actionRoute,
  }) async {
    final existing = (await _db.getNotifications()).where((n) => n.id == id);
    if (existing.isNotEmpty) {
      final current = existing.first;
      if (current.title == title &&
          current.message == message &&
          current.priority == priority) {
        return;
      }
      await _db.insertNotification(
        current.copyWith(
          title: title,
          message: message,
          priority: priority,
          isRead: false,
        ),
      );
      return;
    }

    await _db.insertNotification(
      SystemNotification(
        id: id,
        type: type,
        target: target,
        priority: priority,
        title: title,
        message: message,
        actionRoute: actionRoute,
        createdAt: DateTime.now(),
      ),
    );
  }
}
