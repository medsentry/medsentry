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
  final int consultationCount;
  final int documentCount;
  final String databaseSize;
  final DateTime? lastBackup;

  DatabaseStats({
    required this.patientCount,
    required this.consultationCount,
    required this.documentCount,
    required this.databaseSize,
    this.lastBackup,
  });

  /// Empty stats for initial state
  factory DatabaseStats.empty() => DatabaseStats(
    patientCount: 0,
    consultationCount: 0,
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
  final db = ref.watch(databaseProvider);

  // Fetch database stats
  final patientCount = await db.getPatientCount();
  final consultationCount = await db.getAllConsultations().then(
    (c) => c.length,
  );
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
      (patientCount * 2 + consultationCount * 3 + documentCount * 5);
  final databaseSize = '${estimatedSize.toStringAsFixed(1)} MB';

  return SettingsData(
    appVersion: '1.0.0+1', // Would use package_info_plus in production
    databaseVersion: 'SQLite 3.0',
    lastSync: DateTime.now().subtract(
      const Duration(hours: 2),
    ), // Mock last sync
    databaseStats: DatabaseStats(
      patientCount: patientCount,
      consultationCount: consultationCount,
      documentCount: documentCount,
      databaseSize: databaseSize,
      lastBackup: DateTime.now().subtract(
        const Duration(days: 7),
      ), // Mock last backup
    ),
    recentAuditLogs: recentAuditLogs,
    timestamp: DateTime.now(),
  );
});
