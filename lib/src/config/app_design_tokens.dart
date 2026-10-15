import 'package:flutter/material.dart';

/// Centralized Design Tokens for MedSentry EMR.
/// Standardizes colors, surfaces, borders, glassmorphism, typography, spacing,
/// radii, component heights, shadows, and animation durations.

abstract final class AppColors {
  // Application Foundations (Dark Healthcare Aesthetic)
  static const Color appBackground = Color(0xFF080909);
  static const Color sidebarBackground = Color(0xFF111214);
  static const Color cardSurface = Color(0xFF111214);
  static const Color elevatedSurface = Color(0xFF191A1C);
  static const Color modalSurface = Color(0xFF141518);
  static const Color inputSurface = Color(0xFF131416);

  // Primary Emerald Accent
  static const Color primaryEmerald = Color(0xFF34D399);
  static const Color primaryEmeraldHover = Color(0xFF6EE7B7);
  static const Color primaryEmeraldDark = Color(0xFF059669);
  static const Color primaryEmeraldDeep = Color(0xFF047857);
  static const Color primaryEmeraldSubtle = Color(0x1F34D399); // 12% opacity
  static const Color primaryEmeraldGlow = Color(0x3334D399); // 20% opacity

  // Typography & Text
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF4B5563);
  static const Color textOnEmerald = Color(0xFF064E3B);

  // Borders & Dividers
  static const Color border = Color(0xFF2C2D30);
  static const Color borderSubtle = Color(0xFF1F2023);
  static const Color borderActive = Color(0xFF3F4045);
  static const Color borderFocus = Color(0xFF34D399);
  static const double borderWidth = 1.0;
  static const double borderWidthActive = 1.5;

  // Semantic Healthcare Status Colors
  // Success / Active / Normal
  static const Color success = Color(0xFF34D399);
  static const Color successBg = Color(0x1F34D399); // 12% opacity
  static const Color successBorder = Color(0x4D34D399); // 30% opacity

  // Pending / Warning / In Review
  static const Color pending = Color(0xFFF59E0B);
  static const Color pendingBg = Color(0x1FF59E0B);
  static const Color pendingBorder = Color(0x4DF59E0B);

  // Critical / Error / Urgent
  static const Color critical = Color(0xFFF87171);
  static const Color criticalBg = Color(0x1FF87171);
  static const Color criticalBorder = Color(0x4DF87171);

  // Information / In Progress
  static const Color info = Color(0xFF60A5FA);
  static const Color infoBg = Color(0x1F60A5FA);
  static const Color infoBorder = Color(0x4D60A5FA);

  // Analytical / Special Accent
  static const Color analytical = Color(0xFFA78BFA);
  static const Color analyticalBg = Color(0x1FA78BFA);
  static const Color analyticalBorder = Color(0x4DA78BFA);

  // Neutral / Archived / Disabled
  static const Color neutral = Color(0xFF9CA3AF);
  static const Color neutralBg = Color(0x1F9CA3AF);
  static const Color neutralBorder = Color(0x4D9CA3AF);

  // Light Theme Overrides (for dual-theme support)
  static const Color lightAppBackground = Color(0xFFF8FAFC);
  static const Color lightSidebarBackground = Color(0xFFFFFFFF);
  static const Color lightCardSurface = Color(0xFFFFFFFF);
  static const Color lightElevatedSurface = Color(0xFFF1F5F9);
  static const Color lightModalSurface = Color(0xFFFFFFFF);
  static const Color lightInputSurface = Color(0xFFF8FAFC);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSubtle = Color(0xFFF1F5F9);
  static const Color lightBorderActive = Color(0xFFCBD5E1);

  // Backward compatibility & semantic aliases
  static const Color lightBackground = lightAppBackground;
  static const Color warning = pending;
  static const Color warningBg = pendingBg;
  static const Color warningBorder = pendingBorder;
  static const Color textTertiary = textMuted;
}

/// Standardized Glassmorphism Design Tokens.
abstract final class AppGlass {
  // Blur Intensities (sigma)
  static const double blurNone = 0.0;
  static const double blurSubtle = 8.0;
  static const double blurNavigation = 16.0;
  static const double blurOverlay = 20.0;
  static const double blurModal = 24.0;

  // Surface Opacities
  static const double opacityNav = 0.85;
  static const double opacityCard = 0.92;
  static const double opacityElevated = 0.88;
  static const double opacityOverlay = 0.90;
  static const double opacityModal = 0.94;

  /// Standard navigation bar glass decoration
  static BoxDecoration navigation({
    Color backgroundColor = AppColors.sidebarBackground,
    Color borderColor = AppColors.borderSubtle,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: backgroundColor.withValues(alpha: opacityNav),
      borderRadius: borderRadius,
      border: Border.all(color: borderColor, width: AppColors.borderWidth),
    );
  }

  /// Standard elevated glass panel decoration
  static BoxDecoration panel({
    Color backgroundColor = AppColors.cardSurface,
    Color borderColor = AppColors.border,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: backgroundColor.withValues(alpha: opacityCard),
      borderRadius: borderRadius ?? AppRadius.roundedMd,
      border: Border.all(color: borderColor, width: AppColors.borderWidth),
    );
  }

  /// Standard floating overlay / dropdown glass decoration
  static BoxDecoration overlay({
    Color backgroundColor = AppColors.elevatedSurface,
    Color borderColor = AppColors.borderActive,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: backgroundColor.withValues(alpha: opacityOverlay),
      borderRadius: borderRadius ?? AppRadius.roundedMd,
      border: Border.all(color: borderColor, width: AppColors.borderWidth),
      boxShadow: AppShadows.overlay,
    );
  }
}

/// Standardized Shadows and Elevation.
abstract final class AppShadows {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> subtle = [
    BoxShadow(color: Color(0x33000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x4D000000),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: -1,
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x66000000),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> overlay = [
    BoxShadow(
      color: Color(0x80000000),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -4,
    ),
  ];

  static const List<BoxShadow> emeraldGlow = [
    BoxShadow(
      color: Color(0x3334D399),
      offset: Offset(0, 0),
      blurRadius: 12,
      spreadRadius: 1,
    ),
  ];
}

/// Centralized Spacing System.
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

/// Consistent Border Radii.
abstract final class AppRadius {
  static const double xs = 4.0;
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 14.0;
  static const double xl = 20.0;
  static const double pill = 999.0;

  static const Radius radiusXs = Radius.circular(xs);
  static const Radius radiusSm = Radius.circular(sm);
  static const Radius radiusMd = Radius.circular(md);
  static const Radius radiusLg = Radius.circular(lg);
  static const Radius radiusXl = Radius.circular(xl);
  static const Radius radiusPill = Radius.circular(pill);

  static const BorderRadius roundedXs = BorderRadius.all(radiusXs);
  static const BorderRadius roundedSm = BorderRadius.all(radiusSm);
  static const BorderRadius roundedMd = BorderRadius.all(radiusMd);
  static const BorderRadius roundedLg = BorderRadius.all(radiusLg);
  static const BorderRadius roundedXl = BorderRadius.all(radiusXl);
  static const BorderRadius roundedPill = BorderRadius.all(radiusPill);
}

/// Standardized Icon Sizes.
abstract final class AppIconSize {
  static const double xs = 14.0;
  static const double sm = 18.0;
  static const double md = 20.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double huge = 40.0;
}

/// Component Standard Heights & Dimensions.
abstract final class AppDimensions {
  static const double inputHeight = 44.0;
  static const double buttonHeight = 44.0;
  static const double buttonHeightSm = 36.0;
  static const double buttonHeightXs = 28.0;
  static const double tableRowHeight = 52.0;
  static const double tableHeaderHeight = 42.0;
  static const double appBarHeight = 64.0;
  static const double topbarHeight = 56.0;
  static const double sidebarExpanded = 228.0;
  static const double sidebarCollapsed = 72.0;
  static const double badgeHeight = 24.0;
  static const double avatarSm = 28.0;
  static const double avatarMd = 36.0;
  static const double avatarLg = 48.0;

  // Standard modal widths
  static const double dialogWidthSm = 480.0;
  static const double dialogWidthMd = 580.0;
  static const double dialogWidthLg = 720.0;
  static const double dialogWidthXl = 920.0;
}

/// Unified Animation Durations.
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
    darkPrimaryColor: Color(0xFF34D399),
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
