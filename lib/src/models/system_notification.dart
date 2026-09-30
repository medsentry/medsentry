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
        'type': type.name,
        'target': target.name,
        'priority': priority.name,
        'title': title,
        'message': message,
        'action_route': actionRoute,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  factory SystemNotification.fromJson(Map<String, dynamic> json) {
    return SystemNotification(
      id: json['id'] as String,
      type: NotificationType.values.byName(json['type'] as String),
      target: NotificationTarget.values.byName(json['target'] as String),
      priority: NotificationPriority.values.byName(json['priority'] as String),
      title: json['title'] as String,
      message: json['message'] as String,
      actionRoute: json['action_route'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
