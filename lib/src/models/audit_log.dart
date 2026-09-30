enum AuditAction {
  create,
  read,
  update,
  delete,
  login,
  logout,
  export,
  print,
  sync,
  backup,
  restore,
  settingsChange,
  passwordChange,
  pinChange,
  roleChange,
  other,
}

class AuditLog {
  final String id;
  final String userId;
  final String? userName;
  final String? userRole;
  final AuditAction action;
  final String entityType;
  final String? entityId;
  final String? patientId;
  final String? patientName;
  final String? description;
  final String? oldValues;
  final String? newValues;
  final String? ipAddress;
  final String? deviceInfo;
  final DateTime timestamp;
  final bool isSynced;
  final DateTime? syncedAt;
  final int? syncStatus;

  AuditLog({
    required this.id,
    required this.userId,
    this.userName,
    this.userRole,
    required this.action,
    required this.entityType,
    this.entityId,
    this.patientId,
    this.patientName,
    this.description,
    this.oldValues,
    this.newValues,
    this.ipAddress,
    this.deviceInfo,
    required this.timestamp,
    this.isSynced = false,
    this.syncedAt,
    this.syncStatus,
  });

  String get actionDisplay {
    switch (action) {
      case AuditAction.create:
        return 'Create';
      case AuditAction.read:
        return 'Read';
      case AuditAction.update:
        return 'Update';
      case AuditAction.delete:
        return 'Delete';
      case AuditAction.login:
        return 'Login';
      case AuditAction.logout:
        return 'Logout';
      case AuditAction.export:
        return 'Export';
      case AuditAction.print:
        return 'Print';
      case AuditAction.sync:
        return 'Sync';
      case AuditAction.backup:
        return 'Backup';
      case AuditAction.restore:
        return 'Restore';
      case AuditAction.settingsChange:
        return 'Settings Change';
      case AuditAction.passwordChange:
        return 'Password Change';
      case AuditAction.pinChange:
        return 'PIN Change';
      case AuditAction.roleChange:
        return 'Role Change';
      case AuditAction.other:
        return 'Other';
    }
  }

  AuditLog copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userRole,
    AuditAction? action,
    String? entityType,
    String? entityId,
    String? patientId,
    String? patientName,
    String? description,
    String? oldValues,
    String? newValues,
    String? ipAddress,
    String? deviceInfo,
    DateTime? timestamp,
    bool? isSynced,
    DateTime? syncedAt,
    int? syncStatus,
  }) {
    return AuditLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      description: description ?? this.description,
      oldValues: oldValues ?? this.oldValues,
      newValues: newValues ?? this.newValues,
      ipAddress: ipAddress ?? this.ipAddress,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole,
      'action': action.name,
      'entity_type': entityType,
      'entity_id': entityId,
      'patient_id': patientId,
      'patient_name': patientName,
      'description': description,
      'old_values': oldValues,
      'new_values': newValues,
      'ip_address': ipAddress,
      'device_info': deviceInfo,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced,
      'synced_at': syncedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      userRole: json['user_role'] as String?,
      action: AuditAction.values.byName(json['action'] as String),
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      patientId: json['patient_id'] as String?,
      patientName: json['patient_name'] as String?,
      description: json['description'] as String?,
      oldValues: json['old_values'] as String?,
      newValues: json['new_values'] as String?,
      ipAddress: json['ip_address'] as String?,
      deviceInfo: json['device_info'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSynced: json['is_synced'] as bool? ?? false,
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
      syncStatus: json['sync_status'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditLog && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
