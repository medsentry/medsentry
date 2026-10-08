import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../models/document.dart';
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
/// across patients, staff, clinics, and documents.
class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeStatus status;
  final IconData? icon;
  final bool isPill;
  final bool showDot;

  const StatusBadge({
    super.key,
    required this.text,
    this.status = BadgeStatus.neutral,
    this.icon,
    this.isPill = true,
    this.showDot = false,
  });

  /// 🟢 Dot status badge (shadcn style micro status indicator)
  factory StatusBadge.dot({
    required String text,
    BadgeStatus status = BadgeStatus.normal,
    bool isPill = true,
  }) {
    return StatusBadge(
      text: text,
      status: status,
      showDot: true,
      isPill: isPill,
    );
  }

  /// 🟢 Active state
  factory StatusBadge.active({String text = 'Active', IconData? icon, bool showDot = false}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.normal,
      icon: icon ?? Icons.check_circle_outline,
      showDot: showDot,
    );
  }

  /// ⚪ Inactive / Disabled state
  factory StatusBadge.inactive({String text = 'Inactive', IconData? icon, bool showDot = false}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.neutral,
      icon: icon ?? Icons.remove_circle_outline,
      showDot: showDot,
    );
  }

  /// 🟡 Pending state
  factory StatusBadge.pending({String text = 'Pending', IconData? icon, bool showDot = false}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.warning,
      icon: icon ?? Icons.schedule_outlined,
      showDot: showDot,
    );
  }

  /// 🟢 Completed state
  factory StatusBadge.completed({String text = 'Completed', IconData? icon, bool showDot = false}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.normal,
      icon: icon ?? Icons.task_alt,
      showDot: showDot,
    );
  }

  /// 🔴 Cancelled state
  factory StatusBadge.cancelled({String text = 'Cancelled', IconData? icon, bool showDot = false}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.critical,
      icon: icon ?? Icons.highlight_off,
      showDot: showDot,
    );
  }

  /// 🔵 In Progress state
  factory StatusBadge.inProgress({String text = 'In Progress', IconData? icon, bool showDot = false}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.info,
      icon: icon ?? Icons.play_circle_outline,
      showDot: showDot,
    );
  }

  /// 🔵 Info state
  factory StatusBadge.info({required String text, IconData? icon, bool showDot = false}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.info,
      icon: icon ?? Icons.info_outline,
      showDot: showDot,
    );
  }

  /// 🟡 Waiting state
  factory StatusBadge.waiting({String text = 'Waiting', IconData? icon, bool showDot = false}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.warning,
      icon: icon ?? Icons.hourglass_empty_outlined,
      showDot: showDot,
    );
  }

  /// 🔴 Urgent / Critical state
  factory StatusBadge.urgent({String text = 'Urgent', IconData? icon, bool showDot = false}) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.critical,
      icon: icon ?? Icons.warning_amber_rounded,
      showDot: showDot,
    );
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
          ] else if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
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
