import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/certificate_service.dart';
import '../services/notification_service.dart';
import 'providers.dart';

/// Extended dashboard statistics for Admin and Staff roles.
class ExtendedDashboardStats {
  final int totalPatients;
  final int newPatientsToday;
  final int activeQueueCount;
  final int consultationsToday;
  final int documentsToday;
  final int longWaitCount;
  final int pendingDocuments;
  final int pendingSyncCount;
  final int activeStaffCount;
  final int failedLoginCount;
  final int archivedPatientCount;
  final int unreadNotifications;
  final List<Patient> recentPatients;
  final List<AuditLog> recentActivity;
  final List<MedicalDocument> pendingDocumentList;
  final DateTime timestamp;

  ExtendedDashboardStats({
    required this.totalPatients,
    required this.newPatientsToday,
    required this.activeQueueCount,
    required this.consultationsToday,
    required this.documentsToday,
    required this.longWaitCount,
    required this.pendingDocuments,
    required this.pendingSyncCount,
    required this.activeStaffCount,
    required this.failedLoginCount,
    required this.archivedPatientCount,
    required this.unreadNotifications,
    required this.recentPatients,
    required this.recentActivity,
    required this.pendingDocumentList,
    required this.timestamp,
  });
}

final extendedDashboardStatsProvider = FutureProvider<ExtendedDashboardStats>((
  ref,
) async {
  ref.keepAlive();
  ref.watch(databaseChangesProvider);
  final db = ref.watch(databaseProvider);
  final user = ref.watch(currentUserProvider);
  final notificationTarget = user?.canManageSystemData == true
      ? NotificationTarget.admin
      : NotificationTarget.staff;

  await ref.read(notificationServiceProvider).refreshSystemNotifications();

  final results = await Future.wait([
    db.getPatientCount(),
    db.getTodayPatientCount(),
    db.getActiveQueueCount(),
    db.getTodayConsultationCount(),
    db.getTodayDocumentCount(),
    db.getLongWaitQueueCount(60),
    db.getPendingDocumentCount(),
    db.getPendingSyncCount(),
    db.getActiveStaffCount(),
    db.getFailedLoginCount(within: const Duration(days: 1)),
    db.getArchivedPatientCount(),
    db.getUnreadNotificationCount(notificationTarget),
    db.getRecentlyUpdatedPatients(5),
    db.getStaffActivityLogs(8),
    db.getPendingDocuments(),
  ]);

  return ExtendedDashboardStats(
    totalPatients: results[0] as int,
    newPatientsToday: results[1] as int,
    activeQueueCount: results[2] as int,
    consultationsToday: results[3] as int,
    documentsToday: results[4] as int,
    longWaitCount: results[5] as int,
    pendingDocuments: results[6] as int,
    pendingSyncCount: results[7] as int,
    activeStaffCount: results[8] as int,
    failedLoginCount: results[9] as int,
    archivedPatientCount: results[10] as int,
    unreadNotifications: results[11] as int,
    recentPatients: results[12] as List<Patient>,
    recentActivity: results[13] as List<AuditLog>,
    pendingDocumentList: results[14] as List<MedicalDocument>,
    timestamp: DateTime.now(),
  );
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(databaseProvider));
});

final systemSettingsProvider = FutureProvider<SystemSettings>((ref) async {
  ref.watch(databaseChangesProvider);
  return ref.watch(databaseProvider).getSystemSettings();
});

final notificationsProvider =
    FutureProvider.family<List<SystemNotification>, NotificationTarget?>((
      ref,
      target,
    ) async {
      ref.watch(databaseChangesProvider);
      return ref.watch(databaseProvider).getNotifications(target: target);
    });

final archivedPatientsProvider = FutureProvider<List<Patient>>((ref) async {
  ref.watch(databaseChangesProvider);
  return ref.watch(databaseProvider).getArchivedPatients();
});

final auditLogsProvider = FutureProvider<List<AuditLog>>((ref) async {
  ref.watch(databaseChangesProvider);
  return ref.watch(databaseProvider).getAllAuditLogs();
});

final certificateServiceProvider = Provider<CertificateService>((ref) {
  return CertificateService();
});
