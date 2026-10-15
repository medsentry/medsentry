import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';
import '../widgets/layout/responsive_layout.dart';

extension BuildContextExtensions on BuildContext {
  /// Easy access to ThemeData
  ThemeData get theme => Theme.of(this);

  /// Easy access to ColorScheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Easy access to TextTheme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Easy check if dark mode is active
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Context-aware background color
  Color get scaffoldBackgroundColor => Theme.of(this).scaffoldBackgroundColor;

  /// Context-aware surface color
  Color get surfaceColor => isDark ? AppColors.cardSurface : AppColors.lightCardSurface;

  /// Context-aware elevated surface color
  Color get elevatedSurfaceColor => isDark ? AppColors.elevatedSurface : AppColors.lightElevatedSurface;

  /// Context-aware primary border color
  Color get borderColor => isDark ? AppColors.border : AppColors.lightBorder;

  /// Context-aware subtle border color
  Color get borderSubtleColor => isDark ? AppColors.borderSubtle : AppColors.lightBorderSubtle;

  /// Access the custom SemanticColors
  SemanticColors get semanticColors {
    final extension = Theme.of(this).extension<SemanticColors>();
    if (extension == null) {
      return const SemanticColors(
        normal: AppColors.success,
        normalBg: AppColors.successBg,
        warning: AppColors.pending,
        warningBg: AppColors.pendingBg,
        critical: AppColors.critical,
        criticalBg: AppColors.criticalBg,
        info: AppColors.info,
        infoBg: AppColors.infoBg,
        neutral: AppColors.neutral,
        neutralBg: AppColors.neutralBg,
        analytical: AppColors.analytical,
        analyticalBg: AppColors.analyticalBg,
      );
    }
    return extension;
  }

  /// Responsive layout helpers
  bool get isMobile => ResponsiveBreakpoints.isMobile(this);
  bool get isTablet => ResponsiveBreakpoints.isTablet(this);
  bool get isDesktop => ResponsiveBreakpoints.isDesktop(this);
  bool get isUltraWide => ResponsiveBreakpoints.isUltraWide(this);

  /// Vertical dimension helpers
  bool get isCompactHeight => ResponsiveBreakpoints.isCompactHeight(this);
  bool get isShortHeight => ResponsiveBreakpoints.isShortHeight(this);

  /// Orientation helpers
  bool get isLandscape => ResponsiveBreakpoints.isLandscape(this);
  bool get isPortrait => ResponsiveBreakpoints.isPortrait(this);

  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Returns responsive value based on screen width
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
    T? ultraWide,
  }) {
    final width = screenWidth;
    if (width < ResponsiveBreakpoints.mobile) {
      return mobile;
    } else if (width <= ResponsiveBreakpoints.tablet) {
      return tablet ?? desktop ?? mobile;
    } else if (width <= ResponsiveBreakpoints.desktop) {
      return desktop ?? tablet ?? mobile;
    } else {
      return ultraWide ?? desktop ?? tablet ?? mobile;
    }
  }
}
