import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../utils/context_extensions.dart';

export 'app_confirm_dialog.dart';
export 'forms/app_form_components.dart';

/// A professional, reusable form dialog widget for MedSentry EMR.
/// Provides consistent styling, responsive sizing, and cohesive dark healthcare
/// presentation across all form-based modals in the application.
class AppFormDialog extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget content;
  final List<Widget>? actions;
  final double? maxWidth;
  final bool isLoading;
  final String? loadingText;
  final EdgeInsets contentPadding;
  final bool showCloseButton;
  final Color? headerColor;
  final VoidCallback? onClose;

  const AppFormDialog({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.content,
    this.actions,
    this.maxWidth = 540,
    this.isLoading = false,
    this.loadingText,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 16, 24, 24),
    this.showCloseButton = true,
    this.headerColor,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompactHeight = screenHeight < 550;
    final isCompactWidth = screenWidth < 600;

    final responsiveMaxWidth = isCompactWidth
        ? screenWidth * 0.95
        : screenWidth <= 1024
        ? screenWidth * 0.82
        : (maxWidth ?? 560.0);

    final responsiveMaxHeight = isCompactHeight
        ? screenHeight * 0.96
        : screenHeight * 0.88;

    final effectiveContentPadding = EdgeInsets.fromLTRB(
      isCompactWidth ? 16.0 : contentPadding.left,
      isCompactHeight ? 12.0 : contentPadding.top,
      isCompactWidth ? 16.0 : contentPadding.right,
      isCompactHeight ? 14.0 : contentPadding.bottom,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompactWidth ? 10 : 16,
        vertical: isCompactHeight ? 8 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: responsiveMaxWidth,
          maxHeight: responsiveMaxHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.modalSurface
                : AppColors.lightModalSurface,
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
              // Header
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.sidebarBackground
                      : AppColors.lightElevatedSurface,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.borderSubtle
                          : AppColors.lightBorderSubtle,
                      width: AppColors.borderWidth,
                    ),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  isCompactWidth ? 16 : 24,
                  isCompactHeight ? 12 : 18,
                  16,
                  isCompactHeight ? 12 : 18,
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: isCompactHeight ? 34 : 40,
                        height: isCompactHeight ? 34 : 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryEmeraldSubtle,
                          borderRadius: AppRadius.roundedSm,
                          border: Border.all(
                            color: AppColors.primaryEmerald.withValues(
                              alpha: 0.25,
                            ),
                            width: AppColors.borderWidth,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: Theme.of(context).colorScheme.primary,
                          size: isCompactHeight ? 18 : 20,
                        ),
                      ),
                      SizedBox(width: isCompactWidth ? 10 : 14),
                    ],
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
                              fontSize: isCompactHeight ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: isCompactHeight ? 11.5 : 12.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (showCloseButton && !isLoading)
                      IconButton(
                        onPressed: onClose ?? () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        tooltip: 'Close',
                      ),
                  ],
                ),
              ),

              // Loading State
              if (isLoading)
                Expanded(
                  child: Container(
                    color: isDark
                        ? AppColors.modalSurface
                        : AppColors.lightModalSurface,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryEmerald,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            loadingText ?? 'Processing...',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.lightTextSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: effectiveContentPadding,
                    child: content,
                  ),
                ),

                // Actions Footer
                if (actions != null && actions!.isNotEmpty)
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
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompactWidth ? 16 : 20,
                      vertical: isCompactHeight ? 10 : 14,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: actions!,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A styled form field wrapper for consistent presentation in dialogs
class AppFormField extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget field;
  final String? helperText;
  final String? errorText;
  final bool required;

  const AppFormField({
    super.key,
    required this.label,
    this.hint,
    required this.field,
    this.helperText,
    this.errorText,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  color: context.semanticColors.critical,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(
            hint!,
            style: TextStyle(
              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              fontSize: 11.5,
            ),
          ),
        ],
        const SizedBox(height: 7),
        field,
        if (helperText != null) ...[
          const SizedBox(height: 5),
          Text(
            helperText!,
            style: TextStyle(
              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              fontSize: 11.5,
            ),
          ),
        ],
        if (errorText != null) ...[
          const SizedBox(height: 5),
          Text(
            errorText!,
            style: TextStyle(
              color: context.semanticColors.critical,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// A styled action button for dialog footers
class AppDialogAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDestructive;
  final IconData? icon;

  const AppDialogAction({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: isDestructive
              ? AppColors.critical
              : AppColors.primaryEmerald,
          foregroundColor: isDestructive
              ? Colors.white
              : AppColors.textOnEmerald,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDestructive ? context.semanticColors.critical : null,
        side: isDestructive
            ? BorderSide(
                color: context.semanticColors.critical.withValues(alpha: 0.35),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    );
  }
}

/// A styled info card for displaying data in dialogs
class AppInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const AppInfoCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor = iconColor ?? AppColors.primaryEmerald;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.elevatedSurface
            : AppColors.lightElevatedSurface,
        borderRadius: AppRadius.roundedMd,
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : AppColors.lightBorderSubtle,
          width: AppColors.borderWidth,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: effectiveIconColor.withValues(alpha: 0.12),
              borderRadius: AppRadius.roundedSm,
            ),
            child: Icon(icon, color: effectiveIconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A styled warning/confirmation card for destructive actions
class AppWarningCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData? icon;

  const AppWarningCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.warning_amber_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.semanticColors.criticalBg,
        borderRadius: AppRadius.roundedMd,
        border: Border.all(
          color: context.semanticColors.critical.withValues(alpha: 0.35),
          width: AppColors.borderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.semanticColors.critical, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.semanticColors.critical,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
