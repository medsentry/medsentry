import 'dart:math';
import '../database/simple_database.dart';
import '../models/audit_log.dart';

class AuditService {
  final SimpleDatabase? _db;

  AuditService([this._db]);

  // Simple UUID generator
  String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // In-memory storage for audit logs (replace with actual database in production)
  final List<AuditLog> _logs = [];

  Future<void> logAction({
    required String userId,
    required AuditAction action,
    required String entityType,
    String? entityId,
    String? patientId,
    String? patientName,
    String? description,
    String? details,
    String? oldValues,
    String? newValues,
    String? userName,
    String? userRole,
    String? ipAddress,
    String? deviceInfo,
  }) async {
    final log = AuditLog(
      id: _generateUuid(),
      userId: userId,
      userName: userName,
      userRole: userRole,
      action: action,
      entityType: entityType,
      entityId: entityId ?? patientId,
      patientId: patientId ?? (entityType == 'patient' ? entityId : null),
      patientName: patientName,
      description: description ?? details,
      oldValues: oldValues,
      newValues: newValues,
      ipAddress: ipAddress,
      deviceInfo: deviceInfo,
      timestamp: DateTime.now(),
      isSynced: false,
    );

    _logs.add(log);
    await _db?.insertAuditLog(log);
  }

  Future<List<AuditLog>> getRecentLogs({int limit = 100}) async {
    if (_db != null) {
      return _db.getRecentAuditLogs(limit);
    }
    return _logs.where((log) => !log.isSynced).take(limit).toList();
  }

  Future<List<AuditLog>> getLogsForPatient(String patientId) async {
    if (_db != null) {
      return _db.getAuditLogsForPatient(patientId);
    }
    return _logs.where((log) => log.patientId == patientId).toList();
  }

  Future<List<AuditLog>> getLogsForUser(String userId) async {
    if (_db != null) {
      final logs = await _db.getRecentAuditLogs(1000);
      return logs.where((log) => log.userId == userId).toList();
    }
    return _logs.where((log) => log.userId == userId).toList();
  }

  Future<void> markAsSynced(String logId) async {
    await _db?.markAuditLogAsSynced(logId);
    final index = _logs.indexWhere((log) => log.id == logId);
    if (index != -1) {
      _logs[index] = _logs[index].copyWith(
        isSynced: true,
        syncedAt: DateTime.now(),
      );
    }
  }

  Future<void> clearOldLogs({int daysToKeep = 90}) async {
    // Compliance audit records are append-only in the local app layer.
    // Retention/purge should be handled only by a formal export/archive policy.
  }
}
