import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/simple_database.dart';
import '../models/models.dart';
import '../services/certificate_service.dart';
import '../services/notification_service.dart';
import 'providers.dart';

/// Extended dashboard statistics for Admin and Staff roles.
class ExtendedDashboardStats {
  final int totalPatients;
  final int newPatientsToday;
  final int documentsToday;
  final int pendingSyncCount;
  final int activeStaffCount;
  final int failedLoginCount;
  final int archivedPatientCount;
  final int unreadNotifications;
  final List<Patient> recentPatients;
  final List<AuditLog> recentActivity;
  final DateTime timestamp;

  ExtendedDashboardStats({
    required this.totalPatients,
    required this.newPatientsToday,
    required this.documentsToday,
    required this.pendingSyncCount,
    required this.activeStaffCount,
    required this.failedLoginCount,
    required this.archivedPatientCount,
    required this.unreadNotifications,
    required this.recentPatients,
    required this.recentActivity,
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
  final clinicId = ref.watch(activeClinicIdProvider);
  final notificationTarget = user?.canManageSystemData == true
      ? NotificationTarget.admin
      : NotificationTarget.staff;

  await ref.read(notificationServiceProvider).refreshSystemNotifications();

  final results = await Future.wait([
    db.getPatientCount(clinicId: clinicId),
    db.getTodayPatientCount(clinicId: clinicId),
    db.getTodayDocumentCount(clinicId: clinicId),
    db.getPendingSyncCount(),
    db.getActiveStaffCount(clinicId: clinicId),
    db.getFailedLoginCount(
      within: const Duration(days: 1),
      clinicId: clinicId,
    ),
    db.getArchivedPatientCount(clinicId: clinicId),
    db.getUnreadNotificationCount(notificationTarget, clinicId: clinicId),
    db.getRecentlyUpdatedPatients(5, clinicId: clinicId),
    db.getStaffActivityLogs(8, clinicId: clinicId),
  ]);

  return ExtendedDashboardStats(
    totalPatients: results[0] as int,
    newPatientsToday: results[1] as int,
    documentsToday: results[2] as int,
    pendingSyncCount: results[3] as int,
    activeStaffCount: results[4] as int,
    failedLoginCount: results[5] as int,
    archivedPatientCount: results[6] as int,
    unreadNotifications: results[7] as int,
    recentPatients: results[8] as List<Patient>,
    recentActivity: results[9] as List<AuditLog>,
    timestamp: DateTime.now(),
  );
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(databaseProvider));
});

class SettingsChangesNotifier extends StateNotifier<int> {
  final SimpleDatabase _db;
  StreamSubscription<int>? _subscription;

  SettingsChangesNotifier(this._db) : super(_db.settingsRevision) {
    _subscription = _db.settingsChanges.listen((newRevision) {
      if (mounted) state = newRevision;
    });
  }

  void refresh() {
    state = _db.settingsRevision;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final settingsChangesProvider =
    StateNotifierProvider<SettingsChangesNotifier, int>((ref) {
  final db = ref.watch(databaseProvider);
  return SettingsChangesNotifier(db);
});

final systemSettingsProvider = FutureProvider<SystemSettings>((ref) async {
  ref.watch(settingsChangesProvider);
  return ref.watch(databaseProvider).getSystemSettings();
});

final notificationsProvider =
    FutureProvider.family<List<SystemNotification>, NotificationTarget?>((
      ref,
      target,
    ) async {
      ref.watch(databaseChangesProvider);
      final clinicId = ref.watch(activeClinicIdProvider);
      return ref.watch(databaseProvider).getNotifications(
        target: target,
        clinicId: clinicId,
      );
    });

final archivedPatientsProvider = FutureProvider<List<Patient>>((ref) async {
  ref.watch(databaseChangesProvider);
  final clinicId = ref.watch(activeClinicIdProvider);
  return ref.watch(databaseProvider).getArchivedPatients(clinicId: clinicId);
});

final auditLogsProvider = FutureProvider<List<AuditLog>>((ref) async {
  ref.watch(databaseChangesProvider);
  final clinicId = ref.watch(activeClinicIdProvider);
  return ref.watch(databaseProvider).getAllAuditLogs(clinicId: clinicId);
});

final issuedCertificatesProvider = FutureProvider<List<IssuedCertificate>>((
  ref,
) async {
  ref.watch(databaseChangesProvider);
  final clinicId = ref.watch(activeClinicIdProvider);
  return ref.watch(databaseProvider).getIssuedCertificates(clinicId: clinicId);
});

final certificateServiceProvider = Provider<CertificateService>((ref) {
  return CertificateService();
});
