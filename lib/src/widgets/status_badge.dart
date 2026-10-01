import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../models/document.dart';
import '../models/queue.dart';
import '../utils/context_extensions.dart';

enum BadgeStatus {
  normal, // Green / Success / Active
  warning, // Amber / Pending / Waiting
  critical, // Red / Urgent / Cancelled
  info, // Blue / In Progress
  neutral, // Gray / Inactive / Archived
}

/// Standardized Healthcare Status Badge for MedSentry EMR.
/// Guarantees consistent semantic color, legible typography, and icon indicators
/// across queue, patients, staff, clinics, and documents.
class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeStatus status;
  final IconData? icon;
  final bool isPill;

  const StatusBadge({
    super.key,
    required this.text,
    this.status = BadgeStatus.neutral,
    this.icon,
    this.isPill = true,
  });

  /// 🟢 Active state
  factory StatusBadge.active({String text = 'Active', IconData? icon}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.normal,
      icon: icon ?? Icons.check_circle_outline,
    );
  }

  /// ⚪ Inactive / Disabled state
  factory StatusBadge.inactive({String text = 'Inactive', IconData? icon}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.neutral,
      icon: icon ?? Icons.remove_circle_outline,
    );
  }

  /// 🟡 Pending state
  factory StatusBadge.pending({String text = 'Pending', IconData? icon}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.warning,
      icon: icon ?? Icons.schedule_outlined,
    );
  }

  /// 🟢 Completed state
  factory StatusBadge.completed({String text = 'Completed', IconData? icon}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.normal,
      icon: icon ?? Icons.task_alt,
    );
  }

  /// 🔴 Cancelled state
  factory StatusBadge.cancelled({String text = 'Cancelled', IconData? icon}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.critical,
      icon: icon ?? Icons.highlight_off,
    );
  }

  /// 🔵 In Progress state
  factory StatusBadge.inProgress({String text = 'In Progress', IconData? icon}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.info,
      icon: icon ?? Icons.play_circle_outline,
    );
  }

  /// 🔵 Info state
  factory StatusBadge.info({required String text, IconData? icon}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.info,
      icon: icon ?? Icons.info_outline,
    );
  }

  /// 🟡 Waiting state
  factory StatusBadge.waiting({String text = 'Waiting', IconData? icon}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.warning,
      icon: icon ?? Icons.hourglass_empty_outlined,
    );
  }

  /// 🔴 Urgent / Critical state
  factory StatusBadge.urgent({String text = 'Urgent', IconData? icon}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.critical,
      icon: icon ?? Icons.warning_amber_rounded,
    );
  }

  /// Factory for QueueStatus
  factory StatusBadge.fromQueueStatus(QueueStatus status) {
    switch (status) {
      case QueueStatus.waiting:
        return StatusBadge.waiting(text: 'Waiting');
      case QueueStatus.inProgress:
        return StatusBadge.inProgress(text: 'In Progress');
      case QueueStatus.completed:
        return StatusBadge.completed(text: 'Completed');
      case QueueStatus.cancelled:
        return StatusBadge.cancelled(text: 'Cancelled');
    }
  }

  /// Factory for Queue Priority
  factory StatusBadge.fromPriority(Priority priority) {
    switch (priority) {
      case Priority.emergency:
        return StatusBadge.urgent(text: 'Emergency');
      case Priority.high:
        return StatusBadge(
          text: 'High Priority',
          status: BadgeStatus.warning,
          icon: Icons.priority_high,
        );
      case Priority.normal:
        return StatusBadge(
          text: 'Normal',
          status: BadgeStatus.info,
          icon: Icons.person_outline,
        );
      case Priority.low:
        return StatusBadge(
          text: 'Low',
          status: BadgeStatus.neutral,
          icon: Icons.arrow_downward,
        );
    }
  }

  /// Factory for DocumentStatus
  factory StatusBadge.fromDocumentStatus(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.verified:
        return StatusBadge.completed(text: 'Verified');
      case DocumentStatus.pending:
        return StatusBadge.pending(text: 'Pending');
      case DocumentStatus.archived:
        return StatusBadge.inactive(text: 'Archived');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    Color textColor;
    Color bgColor;

    switch (status) {
      case BadgeStatus.normal:
        textColor = colors.normal;
        bgColor = colors.normalBg;
        break;
      case BadgeStatus.warning:
        textColor = colors.warning;
        bgColor = colors.warningBg;
        break;
      case BadgeStatus.critical:
        textColor = colors.critical;
        bgColor = colors.criticalBg;
        break;
      case BadgeStatus.info:
        textColor = colors.info;
        bgColor = colors.infoBg;
        break;
      case BadgeStatus.neutral:
        textColor = colors.neutral;
        bgColor = colors.neutralBg;
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: isDark ? textColor.withValues(alpha: 0.15) : bgColor,
        borderRadius: isPill ? AppRadius.roundedPill : AppRadius.roundedSm,
        border: Border.all(
          color: textColor.withValues(alpha: isDark ? 0.4 : 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppIconSize.xs, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
