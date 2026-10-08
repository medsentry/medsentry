import 'package:flutter/material.dart' show Brightness, ThemeMode;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import '../config/app_design_tokens.dart';

/// Maps Material ThemeMode to shadcn_flutter ThemeMode.
shad.ThemeMode toShadThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return shad.ThemeMode.light;
    case ThemeMode.dark:
      return shad.ThemeMode.dark;
    case ThemeMode.system:
      return shad.ThemeMode.system;
  }
}

/// Configures and returns a modern shadcn_flutter ThemeData aligned with MedSentry tokens.
shad.ThemeData buildShadcnTheme(
  Brightness brightness, {
  AppAccentTheme accentTheme = AppAccentTheme.emerald,
}) {
  final isDark = brightness == Brightness.dark;
  final baseScheme =
      isDark ? shad.ColorSchemes.darkZinc : shad.ColorSchemes.lightZinc;

  final primaryColor =
      isDark ? accentTheme.darkPrimaryColor : accentTheme.primaryColor;

  final customScheme = baseScheme.copyWith(
    primary: () => primaryColor,
  );

  return isDark
      ? shad.ThemeData.dark(
          colorScheme: customScheme,
          radius: 0.5,
        )
      : shad.ThemeData(
          colorScheme: customScheme,
          radius: 0.5,
        );
}
