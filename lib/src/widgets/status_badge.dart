import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../models/document.dart';
import '../utils/context_extensions.dart';

enum BadgeStatus {
  normal, // Green / Success / Active (#34D399)
  warning, // Amber / Pending / Waiting (#F59E0B)
  critical, // Red / Urgent / Cancelled (#F87171)
  info, // Blue / In Progress (#60A5FA)
  neutral, // Gray / Inactive / Archived (#9CA3AF)
  analytical, // Violet / Clinical Metric (#A78BFA)
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

  /// 🟢 Micro status indicator with colored dot
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

  /// 🟢 Active / Success state
  factory StatusBadge.active({
    String text = 'Active',
    IconData? icon,
    bool showDot = false,
  }) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.normal,
      icon: icon ?? Icons.check_circle_outline,
      showDot: showDot,
    );
  }

  /// 🟢 Normal / Success / Create state
  factory StatusBadge.normal({
    required String text,
    IconData? icon,
    bool showDot = false,
    bool isPill = true,
  }) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.normal,
      icon: icon ?? Icons.check_circle_outline,
      showDot: showDot,
      isPill: isPill,
    );
  }

  /// 🔴 Critical / Urgent / Danger state
  factory StatusBadge.critical({
    required String text,
    IconData? icon,
    bool showDot = false,
    bool isPill = true,
  }) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.critical,
      icon: icon ?? Icons.error_outline,
      showDot: showDot,
      isPill: isPill,
    );
  }

  /// ⚪ Neutral / Default / Other state
  factory StatusBadge.neutral({
    required String text,
    IconData? icon,
    bool showDot = false,
    bool isPill = true,
  }) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.neutral,
      icon: icon,
      showDot: showDot,
      isPill: isPill,
    );
  }

  /// ⚪ Inactive / Disabled state
  factory StatusBadge.inactive({
    String text = 'Inactive',
    IconData? icon,
    bool showDot = false,
  }) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.neutral,
      icon: icon ?? Icons.remove_circle_outline,
      showDot: showDot,
    );
  }

  /// 🟡 Pending / Warning state
  factory StatusBadge.pending({
    String text = 'Pending',
    IconData? icon,
    bool showDot = false,
  }) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.warning,
      icon: icon ?? Icons.schedule_outlined,
      showDot: showDot,
    );
  }

  /// 🟢 Completed state
  factory StatusBadge.completed({
    String text = 'Completed',
    IconData? icon,
    bool showDot = false,
  }) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.normal,
      icon: icon ?? Icons.task_alt,
      showDot: showDot,
    );
  }

  /// 🔴 Cancelled / Error state
  factory StatusBadge.cancelled({
    String text = 'Cancelled',
    IconData? icon,
    bool showDot = false,
  }) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.critical,
      icon: icon ?? Icons.highlight_off,
      showDot: showDot,
    );
  }

  /// 🔵 In Progress state
  factory StatusBadge.inProgress({
    String text = 'In Progress',
    IconData? icon,
    bool showDot = false,
  }) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.info,
      icon: icon ?? Icons.play_circle_outline,
      showDot: showDot,
    );
  }

  /// 🔵 Info state
  factory StatusBadge.info({
    required String text,
    IconData? icon,
    bool showDot = false,
  }) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.info,
      icon: icon ?? Icons.info_outline,
      showDot: showDot,
    );
  }

  /// 🟣 Analytical / Category state
  factory StatusBadge.analytical({
    required String text,
    IconData? icon,
    bool showDot = false,
  }) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.analytical,
      icon: icon,
      showDot: showDot,
    );
  }

  /// 🟡 Waiting state
  factory StatusBadge.waiting({
    String text = 'Waiting',
    IconData? icon,
    bool showDot = false,
  }) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.warning,
      icon: icon ?? Icons.hourglass_empty_outlined,
      showDot: showDot,
    );
  }

  /// 🔴 Urgent / Critical state
  factory StatusBadge.urgent({
    String text = 'Urgent',
    IconData? icon,
    bool showDot = false,
  }) {
    return StatusBadge(
      text: text,
      status: BadgeStatus.critical,
      icon: icon ?? Icons.warning_amber_rounded,
      showDot: showDot,
    );
  }

  /// Factory for archived document status.
  factory StatusBadge.fromDocumentStatus(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.active:
        return StatusBadge.active(text: 'Active');
      case DocumentStatus.archived:
        return StatusBadge.inactive(text: 'Archived');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color textColor;
    Color bgColor;
    Color borderColor;

    switch (status) {
      case BadgeStatus.normal:
        textColor = colors.normal;
        bgColor = isDark ? AppColors.successBg : colors.normalBg;
        borderColor = isDark
            ? AppColors.successBorder
            : colors.normal.withValues(alpha: 0.25);
        break;
      case BadgeStatus.warning:
        textColor = colors.warning;
        bgColor = isDark ? AppColors.pendingBg : colors.warningBg;
        borderColor = isDark
            ? AppColors.pendingBorder
            : colors.warning.withValues(alpha: 0.25);
        break;
      case BadgeStatus.critical:
        textColor = colors.critical;
        bgColor = isDark ? AppColors.criticalBg : colors.criticalBg;
        borderColor = isDark
            ? AppColors.criticalBorder
            : colors.critical.withValues(alpha: 0.25);
        break;
      case BadgeStatus.info:
        textColor = colors.info;
        bgColor = isDark ? AppColors.infoBg : colors.infoBg;
        borderColor = isDark
            ? AppColors.infoBorder
            : colors.info.withValues(alpha: 0.25);
        break;
      case BadgeStatus.neutral:
        textColor = colors.neutral;
        bgColor = isDark ? AppColors.neutralBg : colors.neutralBg;
        borderColor = isDark
            ? AppColors.neutralBorder
            : colors.neutral.withValues(alpha: 0.25);
        break;
      case BadgeStatus.analytical:
        textColor = colors.analytical;
        bgColor = isDark ? AppColors.analyticalBg : colors.analyticalBg;
        borderColor = isDark
            ? AppColors.analyticalBorder
            : colors.analytical.withValues(alpha: 0.25);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: isPill ? AppRadius.roundedPill : AppRadius.roundedSm,
        border: Border.all(color: borderColor, width: AppColors.borderWidth),
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
