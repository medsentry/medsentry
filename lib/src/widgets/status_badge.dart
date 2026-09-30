import 'package:flutter/material.dart';
import '../utils/context_extensions.dart';

enum BadgeStatus {
  normal, // Green
  warning, // Amber
  critical, // Red
  info, // Blue
  neutral, // Gray
}

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeStatus status;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    this.status = BadgeStatus.neutral,
    this.icon,
  });

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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
