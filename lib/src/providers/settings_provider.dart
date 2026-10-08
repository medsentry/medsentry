import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

/// Settings data model
class SettingsData {
  final String appVersion;
  final String databaseVersion;
  final DateTime? lastSync;
  final DatabaseStats databaseStats;
  final List<AuditLogEntry> recentAuditLogs;
  final DateTime timestamp;

  SettingsData({
    required this.appVersion,
    required this.databaseVersion,
    this.lastSync,
    required this.databaseStats,
    required this.recentAuditLogs,
    required this.timestamp,
  });

  /// Empty data for initial state
  factory SettingsData.empty() => SettingsData(
    appVersion: '1.0.0',
    databaseVersion: 'SQLite 3.0',
    lastSync: null,
    databaseStats: DatabaseStats.empty(),
    recentAuditLogs: [],
    timestamp: DateTime.now(),
  );
}

/// Database statistics
class DatabaseStats {
  final int patientCount;
  final int documentCount;
  final String databaseSize;
  final DateTime? lastBackup;

  DatabaseStats({
    required this.patientCount,
    required this.documentCount,
    required this.databaseSize,
    this.lastBackup,
  });

  /// Empty stats for initial state
  factory DatabaseStats.empty() => DatabaseStats(
    patientCount: 0,
    documentCount: 0,
    databaseSize: '0 MB',
    lastBackup: null,
  );
}

/// Audit log entry
class AuditLogEntry {
  final String id;
  final String action;
  final String user;
  final DateTime timestamp;
  final String? details;

  AuditLogEntry({
    required this.id,
    required this.action,
    required this.user,
    required this.timestamp,
    this.details,
  });
}

/// Provider for settings data
final settingsDataProvider = FutureProvider<SettingsData>((ref) async {
  ref.watch(databaseChangesProvider);
  final lastSync = ref.watch(lastSyncTimeProvider);
  final db = ref.watch(databaseProvider);

  // Fetch database stats
  final patientCount = await db.getPatientCount();
  final documentCount = await db.getDocumentCount();

  // Get recent audit logs
  final auditLogs = await db.getRecentAuditLogs(5);
  final recentAuditLogs = auditLogs
      .map(
        (log) => AuditLogEntry(
          id: log.id,
          action: log.action.name,
          user: log.userName ?? log.userId,
          timestamp: log.timestamp,
          details: log.description,
        ),
      )
      .toList();

  // Calculate database size (simplified estimation)
  final estimatedSize =
      (patientCount * 2 + documentCount * 5);
  final databaseSize = estimatedSize > 0 ? 'Stored on this device' : 'Empty';

  return SettingsData(
    appVersion: '1.0.0+1', // Would use package_info_plus in production
    databaseVersion: 'SQLite 3.0',
    lastSync: lastSync,
    databaseStats: DatabaseStats(
      patientCount: patientCount,
      documentCount: documentCount,
      databaseSize: databaseSize,
      lastBackup: null,
    ),
    recentAuditLogs: recentAuditLogs,
    timestamp: DateTime.now(),
  );
});
