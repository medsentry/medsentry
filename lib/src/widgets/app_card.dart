import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';

/// Card style variants
enum AppCardVariant {
  standard, // Charcoal surface (#111214), subtle border
  elevated, // Elevated surface (#191A1C), soft shadow
  glass, // Subtle glassmorphic panel with blur
  outline, // Transparent background with crisp border
}

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
  final BorderRadius? borderRadius;
  final AppCardVariant variant;
  final bool expandContent;

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
    this.borderRadius,
    this.variant = AppCardVariant.standard,
    this.expandContent = false,
  });

  /// Factory for an elevated card
  factory AppCard.elevated({
    Key? key,
    Widget? title,
    String? titleText,
    String? subtitle,
    IconData? icon,
    Widget? headerAction,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.lg),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    VoidCallback? onTap,
  }) {
    return AppCard(
      key: key,
      title: title,
      titleText: titleText,
      subtitle: subtitle,
      icon: icon,
      headerAction: headerAction,
      padding: padding,
      margin: margin,
      onTap: onTap,
      variant: AppCardVariant.elevated,
      child: child,
    );
  }

  /// Factory for a glass panel card
  factory AppCard.glass({
    Key? key,
    Widget? title,
    String? titleText,
    String? subtitle,
    IconData? icon,
    Widget? headerAction,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.lg),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    VoidCallback? onTap,
  }) {
    return AppCard(
      key: key,
      title: title,
      titleText: titleText,
      subtitle: subtitle,
      icon: icon,
      headerAction: headerAction,
      padding: padding,
      margin: margin,
      onTap: onTap,
      variant: AppCardVariant.glass,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasHeader =
        title != null ||
        titleText != null ||
        icon != null ||
        headerAction != null;

    // Flat panels: one tight 8px radius, a 1px border and no resting shadow,
    // matching the restyled patient, document and certificate screens.
    final effectiveBorderRadius =
        borderRadius ?? const BorderRadius.all(Radius.circular(8));

    Color effectiveBgColor;
    List<BoxShadow> effectiveShadows = AppShadows.none;

    switch (variant) {
      case AppCardVariant.standard:
        effectiveBgColor =
            backgroundColor ??
            (isDark ? AppColors.cardSurface : AppColors.lightCardSurface);
        effectiveShadows = AppShadows.none;
        break;
      case AppCardVariant.elevated:
        effectiveBgColor =
            backgroundColor ??
            (isDark
                ? AppColors.elevatedSurface
                : AppColors.lightElevatedSurface);
        effectiveShadows = AppShadows.card;
        break;
      case AppCardVariant.glass:
        effectiveBgColor =
            backgroundColor ??
            (isDark
                ? AppColors.cardSurface.withValues(alpha: AppGlass.opacityCard)
                : Colors.white.withValues(alpha: 0.85));
        effectiveShadows = AppShadows.subtle;
        break;
      case AppCardVariant.outline:
        effectiveBgColor = Colors.transparent;
        effectiveShadows = AppShadows.none;
        break;
    }

    final border =
        borderSide ??
        BorderSide(
          color: isDark ? AppColors.border : AppColors.lightBorder,
          width: AppColors.borderWidth,
        );

    final Widget paddedChild = Padding(padding: padding, child: child);
    final Widget cardContent;

    if (hasHeader) {
      final headerElements = [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: AppIconSize.sm,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
                const SizedBox(width: AppSpacing.sm + 2),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (titleText != null)
                      Text(
                        titleText!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      )
                    else
                      ?title,
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
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
          color: isDark ? AppColors.borderSubtle : AppColors.lightBorderSubtle,
        ),
      ];

      cardContent = expandContent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...headerElements,
                Expanded(child: paddedChild),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [...headerElements, paddedChild],
            );
    } else {
      cardContent = expandContent
          ? SizedBox.expand(child: paddedChild)
          : paddedChild;
    }

    Widget cardWidget = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: effectiveBorderRadius,
        border: Border.fromBorderSide(border),
        boxShadow: effectiveShadows,
      ),
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: effectiveBorderRadius,
                onTap: onTap,
                hoverColor: isDark
                    ? AppColors.elevatedSurface.withValues(alpha: 0.4)
                    : AppColors.lightElevatedSurface,
                child: cardContent,
              ),
            )
          : cardContent,
    );

    if (variant == AppCardVariant.glass) {
      return ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppGlass.blurSubtle,
            sigmaY: AppGlass.blurSubtle,
          ),
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}

/// Standardized KPI Statistic Card for MedSentry EMR.
class AppStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? trendText;
  final bool? isTrendPositive;

  const AppStatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.trailing,
    this.onTap,
    this.trendText,
    this.isTrendPositive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveIconColor = iconColor ?? AppColors.primaryEmerald;
    final effectiveIconBg =
        iconBackgroundColor ?? effectiveIconColor.withValues(alpha: 0.12);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: effectiveIconBg,
                  borderRadius: AppRadius.roundedSm,
                  border: Border.all(
                    color: effectiveIconColor.withValues(alpha: 0.25),
                    width: AppColors.borderWidth,
                  ),
                ),
                child: Icon(icon, size: 20, color: effectiveIconColor),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.lightTextSecondary,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.lightTextPrimary,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          if (subtitle != null || trendText != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                if (trendText != null) ...[
                  Icon(
                    isTrendPositive == true
                        ? Icons.trending_up
                        : (isTrendPositive == false
                              ? Icons.trending_down
                              : Icons.trending_flat),
                    size: 14,
                    color: isTrendPositive == true
                        ? AppColors.success
                        : (isTrendPositive == false
                              ? AppColors.critical
                              : AppColors.neutral),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trendText!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isTrendPositive == true
                          ? AppColors.success
                          : (isTrendPositive == false
                                ? AppColors.critical
                                : AppColors.neutral),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (subtitle != null)
                  Expanded(
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
