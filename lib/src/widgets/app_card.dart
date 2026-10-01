import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';

/// Standardized Card container for MedSentry EMR.
/// Provides consistent padding, subtle healthcare borders, optional header/actions,
/// and responsive layout adaptation.
class AppCard extends StatelessWidget {
  final Widget? title;
  final String? titleText;
  final String? subtitle;
  final IconData? icon;
  final Widget? headerAction;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final BorderSide? borderSide;

  const AppCard({
    super.key,
    this.title,
    this.titleText,
    this.subtitle,
    this.icon,
    this.headerAction,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.backgroundColor,
    this.onTap,
    this.borderSide,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final hasHeader =
        title != null || titleText != null || icon != null || headerAction != null;

    final border = borderSide ??
        BorderSide(
          color: colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.35 : 0.75,
          ),
          width: 1,
        );

    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasHeader) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.roundedSm,
                    ),
                    child: Icon(
                      icon,
                      size: AppIconSize.sm,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (titleText != null)
                        Text(
                          titleText!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        )
                      else
                        ?title,
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?headerAction,
              ],
            ),
          ),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.25 : 0.6,
            ),
          ),
        ],
        Padding(
          padding: padding,
          child: child,
        ),
      ],
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardTheme.color ?? colorScheme.surface,
        borderRadius: AppRadius.roundedLg,
        border: Border.fromBorderSide(border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppRadius.roundedLg,
                onTap: onTap,
                child: cardContent,
              ),
            )
          : cardContent,
    );
  }
}
