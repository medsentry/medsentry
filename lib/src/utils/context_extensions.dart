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

  /// Access the custom SemanticColors
  SemanticColors get semanticColors {
    final extension = Theme.of(this).extension<SemanticColors>();
    if (extension == null) {
      // Fallback colors if not found
      return SemanticColors(
        normal: MedSentryColors.statusNormal,
        normalBg: MedSentryColors.statusNormalBg,
        warning: MedSentryColors.statusWarning,
        warningBg: MedSentryColors.statusWarningBg,
        critical: MedSentryColors.statusCritical,
        criticalBg: MedSentryColors.statusCriticalBg,
        info: MedSentryColors.statusInfo,
        infoBg: MedSentryColors.statusInfoBg,
        neutral: MedSentryColors.statusNeutral,
        neutralBg: MedSentryColors.statusNeutralBg,
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
