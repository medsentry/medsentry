import 'package:flutter/material.dart';

/// Centralized Design Tokens for MedSentry EMR.
/// Standardizes spacing, radii, icon sizes, standard heights, and animation durations.
abstract final class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;
}

abstract final class AppRadius {
  static const double xs = 4.0;
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 14.0;
  static const double xl = 20.0;
  static const double pill = 999.0;

  static const BorderRadius roundedXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius roundedPill = BorderRadius.all(Radius.circular(pill));
}

abstract final class AppIconSize {
  static const double xs = 14.0;
  static const double sm = 18.0;
  static const double md = 22.0;
  static const double lg = 28.0;
  static const double xl = 36.0;
}

abstract final class AppDimensions {
  static const double inputHeight = 44.0;
  static const double buttonHeight = 44.0;
  static const double appBarHeight = 64.0;
  static const double sidebarExpanded = 228.0;
  static const double sidebarCollapsed = 72.0;

  // Standard modal widths
  static const double dialogWidthSm = 480.0;
  static const double dialogWidthMd = 580.0;
  static const double dialogWidthLg = 680.0;
  static const double dialogWidthXl = 840.0;
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 350);
}

/// Accent color theme presets for MedSentry
enum AppAccentTheme {
  emerald(
    id: 'emerald',
    label: 'MedSentry Green',
    primaryColor: Color(0xFF15803D),
    darkPrimaryColor: Color(0xFF4ADE80),
    secondaryColor: Color(0xFF047857),
  ),
  blue(
    id: 'blue',
    label: 'Clinical Blue',
    primaryColor: Color(0xFF0284C7),
    darkPrimaryColor: Color(0xFF38BDF8),
    secondaryColor: Color(0xFF0369A1),
  ),
  teal(
    id: 'teal',
    label: 'Medical Teal',
    primaryColor: Color(0xFF0D9488),
    darkPrimaryColor: Color(0xFF2DD4BF),
    secondaryColor: Color(0xFF0F766E),
  ),
  indigo(
    id: 'indigo',
    label: 'Royal Indigo',
    primaryColor: Color(0xFF4F46E5),
    darkPrimaryColor: Color(0xFF818CF8),
    secondaryColor: Color(0xFF4338CA),
  ),
  purple(
    id: 'purple',
    label: 'Deep Purple',
    primaryColor: Color(0xFF7C3AED),
    darkPrimaryColor: Color(0xFFA78BFA),
    secondaryColor: Color(0xFF6D28D9),
  ),
  amber(
    id: 'amber',
    label: 'Warm Amber',
    primaryColor: Color(0xFFD97706),
    darkPrimaryColor: Color(0xFFFBBF24),
    secondaryColor: Color(0xFFB45309),
  ),
  rose(
    id: 'rose',
    label: 'Healthcare Rose',
    primaryColor: Color(0xFFE11D48),
    darkPrimaryColor: Color(0xFFFB7185),
    secondaryColor: Color(0xFFBE123C),
  );

  final String id;
  final String label;
  final Color primaryColor;
  final Color darkPrimaryColor;
  final Color secondaryColor;

  const AppAccentTheme({
    required this.id,
    required this.label,
    required this.primaryColor,
    required this.darkPrimaryColor,
    required this.secondaryColor,
  });

  static AppAccentTheme fromId(String? id) {
    return AppAccentTheme.values.firstWhere(
      (theme) => theme.id == id,
      orElse: () => AppAccentTheme.emerald,
    );
  }
}
