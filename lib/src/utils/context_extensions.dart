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
}
