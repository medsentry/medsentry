enum NotificationType {
  incompleteRecord,
  syncFailed,
  pendingDocument,
  suspiciousActivity,
  systemUpdate,
  queueAlert,
  general,
}

enum NotificationTarget { admin, staff, all }

enum NotificationPriority { low, normal, high, urgent }

class SystemNotification {
  final String id;
  final String? clinicId;
  final NotificationType type;
  final NotificationTarget target;
  final NotificationPriority priority;
  final String title;
  final String message;
  final String? actionRoute;
  final bool isRead;
  final DateTime createdAt;

  const SystemNotification({
    required this.id,
    this.clinicId,
    required this.type,
    required this.target,
    required this.priority,
    required this.title,
    required this.message,
    this.actionRoute,
    this.isRead = false,
    required this.createdAt,
  });

  SystemNotification copyWith({
    String? id,
    String? clinicId,
    NotificationType? type,
    NotificationTarget? target,
    NotificationPriority? priority,
    String? title,
    String? message,
    String? actionRoute,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return SystemNotification(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      type: type ?? this.type,
      target: target ?? this.target,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      message: message ?? this.message,
      actionRoute: actionRoute ?? this.actionRoute,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (clinicId != null) 'clinic_id': clinicId,
        'type': type.name,
        'target': target.name,
        'priority': priority.name,
        'title': title,
        'message': message,
        'action_route': actionRoute,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  static T _safeEnumValue<T extends Enum>(List<T> values, dynamic value, T fallback) {
    if (value is String) {
      final needle = value.trim().toLowerCase();
      for (final e in values) {
        if (e.name.toLowerCase() == needle) return e;
      }
    }
    return fallback;
  }

  factory SystemNotification.fromJson(Map<String, dynamic> json) {
    return SystemNotification(
      id: json['id'] as String,
      clinicId: json['clinic_id'] as String?,
      type: _safeEnumValue(NotificationType.values, json['type'], NotificationType.general),
      target: _safeEnumValue(NotificationTarget.values, json['target'], NotificationTarget.all),
      priority: _safeEnumValue(NotificationPriority.values, json['priority'], NotificationPriority.normal),
      title: json['title'] as String,
      message: json['message'] as String,
      actionRoute: json['action_route'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
