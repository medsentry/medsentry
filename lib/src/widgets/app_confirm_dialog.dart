import 'package:flutter/material.dart';

import '../config/app_design_tokens.dart';

/// Semantic alert level for [AppConfirmDialog].
enum ConfirmDialogType {
  info,
  warning,
  danger,
}

/// A modern, consistent confirmation dialog widget for MedSentry EMR.
/// Replaces ad-hoc AlertDialogs for destructive or impactful user actions.
class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final Widget? content;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final IconData? icon;
  final ConfirmDialogType type;
  final double maxWidth;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.content,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    this.icon,
    this.type = ConfirmDialogType.warning,
    this.maxWidth = 480,
  });

  /// Displays the confirmation dialog and returns true if confirmed, false otherwise.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    Widget? content,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
    ConfirmDialogType type = ConfirmDialogType.warning,
    double maxWidth = 480,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmDialog(
        title: title,
        message: message,
        content: content,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        icon: icon,
        type: type,
        maxWidth: maxWidth,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveType = isDestructive ? ConfirmDialogType.danger : type;

    final Color badgeColor;
    final Color badgeBg;
    final Color badgeBorder;
    final IconData defaultIcon;

    switch (effectiveType) {
      case ConfirmDialogType.danger:
        badgeColor = AppColors.critical;
        badgeBg = AppColors.criticalBg;
        badgeBorder = AppColors.criticalBorder;
        defaultIcon = Icons.warning_amber_rounded;
      case ConfirmDialogType.warning:
        badgeColor = AppColors.pending;
        badgeBg = AppColors.pendingBg;
        badgeBorder = AppColors.pendingBorder;
        defaultIcon = Icons.help_outline_rounded;
      case ConfirmDialogType.info:
        badgeColor = AppColors.primaryEmerald;
        badgeBg = AppColors.primaryEmeraldSubtle;
        badgeBorder = AppColors.primaryEmerald.withValues(alpha: 0.25);
        defaultIcon = Icons.info_outline_rounded;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final responsiveMaxWidth = screenWidth < 520 ? screenWidth * 0.94 : maxWidth;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: responsiveMaxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.modalSurface : AppColors.lightModalSurface,
            borderRadius: AppRadius.roundedLg,
            border: Border.all(
              color: isDark ? AppColors.border : AppColors.lightBorder,
              width: AppColors.borderWidth,
            ),
            boxShadow: AppShadows.overlay,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header & Body
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Icon(
                        icon ?? defaultIcon,
                        color: badgeColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.lightTextPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            message,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.lightTextSecondary,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                          if (content != null) ...[
                            const SizedBox(height: 14),
                            content!,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons footer
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.sidebarBackground
                      : AppColors.lightElevatedSurface,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.borderSubtle
                          : AppColors.lightBorderSubtle,
                      width: AppColors.borderWidth,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.roundedSm,
                        ),
                      ),
                      child: Text(cancelLabel),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: isDestructive
                            ? AppColors.critical
                            : AppColors.primaryEmerald,
                        foregroundColor: isDestructive
                            ? Colors.white
                            : AppColors.textOnEmerald,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.roundedSm,
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

