import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

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
  bool get isMobile => MediaQuery.sizeOf(this).width < 600.0;
  bool get isTablet {
    final width = MediaQuery.sizeOf(this).width;
    return width >= 600.0 && width <= 1024.0;
  }
  bool get isDesktop => MediaQuery.sizeOf(this).width > 1024.0;
  bool get isUltraWide => MediaQuery.sizeOf(this).width > 1600.0;

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
    if (width < 600.0) {
      return mobile;
    } else if (width <= 1024.0) {
      return tablet ?? desktop ?? mobile;
    } else if (width <= 1600.0) {
      return desktop ?? tablet ?? mobile;
    } else {
      return ultraWide ?? desktop ?? tablet ?? mobile;
    }
  }
}
