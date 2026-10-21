import 'package:flutter/material.dart';

/// Centralized Design Tokens for MedSentry EMR.
/// Standardizes colors, surfaces, borders, glassmorphism, typography, spacing,
/// radii, component heights, shadows, and animation durations.

abstract final class AppColors {
  // Dark mode: the obsidian clinical theme with the emerald accent.
  static const Color appBackground = Color(0xFF0C0D11);
  static const Color sidebarBackground = Color(0xFF111216);
  static const Color cardSurface = Color(0xFF16171D);
  static const Color elevatedSurface = Color(0xFF1D1F27);
  static const Color modalSurface = Color(0xFF181A22);
  static const Color inputSurface = Color(0xFF16171E);

  // Brand greens. [primaryEmerald] is the dark-mode emerald; on light
  // surfaces use [accent], which switches to bottle green there.
  static const Color primaryEmerald = Color(0xFF34D399);
  static const Color primaryEmeraldHover = Color(0xFF6EE7B7);
  static const Color primaryEmeraldDark = Color(0xFF1D5C45); // bottle green
  static const Color primaryEmeraldDeep = Color(0xFF174A38);

  /// The brand green for text, icons and filled buttons: bottle green on
  /// paper (7.6:1) and emerald on obsidian.
  static Color accent(bool isDark) =>
      isDark ? primaryEmerald : primaryEmeraldDark;
  static const Color primaryEmeraldSubtle = Color(0x1F34D399); // 12% opacity
  static const Color primaryEmeraldGlow = Color(0x3334D399); // 20% opacity

  // Typography & Text (dark mode)
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF8E929B);
  static const Color textMuted = Color(0xFF636773);
  static const Color textDisabled = Color(0xFF4B5563);
  static const Color textOnEmerald = Color(0xFF064E3B);

  // Borders & Dividers
  static const Color border = Color(0xFF232631);
  static const Color borderSubtle = Color(0xFF1A1C24);
  static const Color borderActive = Color(0xFF323645);
  static const Color borderFocus = primaryEmerald;
  static const double borderWidth = 1.0;
  static const double borderWidthActive = 1.5;

  // Semantic Healthcare Status Colors (dark-mode values; the light-mode
  // values live in [SemanticColors] in theme_provider.dart)
  // Success / Active / Normal
  static const Color success = primaryEmerald;
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

  // Light theme: ledger paper and ballpen ink. Text meets WCAG AA (4.5:1)
  // on every light surface, including the elevated rule green (#E4EBE3):
  // primary 14.5:1, secondary 7.2:1, muted 5.1:1.
  static const Color lightAppBackground = Color(0xFFEEF2EC);
  static const Color lightSidebarBackground = Color(0xFFF9FBF8);
  static const Color lightCardSurface = Color(0xFFF9FBF8);
  static const Color lightElevatedSurface = Color(0xFFE4EBE3);
  static const Color lightModalSurface = Color(0xFFF9FBF8);
  static const Color lightInputSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF16202C);
  static const Color lightTextSecondary = Color(0xFF44515E);
  static const Color lightTextMuted = Color(0xFF56636F);
  static const Color lightBorder = Color(0xFFC9D6CB);
  static const Color lightBorderSubtle = Color(0xFFDCE5DC);
  static const Color lightBorderActive = Color(0xFFA9BBAD);

  /// The ledger pad's red margin rule, drawn under table headers in light
  /// mode. Dark mode keeps its plain border instead.
  static Color ledgerRule(bool isDark) =>
      isDark ? border : const Color(0xFFB03328);

  // Backward compatibility & semantic aliases
  static const Color lightBackground = lightAppBackground;
  static const Color warning = pending;
  static const Color warningBg = pendingBg;
  static const Color warningBorder = pendingBorder;
  static const Color textTertiary = textMuted;
  static const Color dangerRed = critical;
  static const Color accentTeal = primaryEmerald;
}

/// Sidebar colours. In light mode the sidebar is the record book's spine:
/// bound in deep green, with the open page shown as a paper tab and a red
/// margin mark. Dark mode keeps the obsidian sidebar with emerald selection.
class AppSpine {
  const AppSpine._({
    required this.background,
    required this.raised,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.hover,
    required this.tab,
    required this.tabText,
    required this.mark,
    this.tileBorder,
  });

  final Color background;
  final Color raised;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color hover;

  /// The selected item's fill and its label/icon colour.
  final Color tab;
  final Color tabText;

  /// The bar beside the selected item and the default badge colour.
  final Color mark;

  /// Outline of the brand tile, if any.
  final Color? tileBorder;

  static const light = AppSpine._(
    background: Color(0xFF173D30),
    raised: Color(0xFF1F4A3B),
    border: Color(0xFF2A5646),
    text: Color(0xFFEEF3EC), // 10.7:1
    textSecondary: Color(0xFFB5CABC), // 7.0:1
    textMuted: Color(0xFF93B3A1), // 5.3:1
    hover: Color(0x14EEF3EC),
    tab: AppColors.lightAppBackground,
    tabText: AppColors.primaryEmeraldDark, // 7.0:1
    mark: Color(0xFFB03328),
  );

  static const dark = AppSpine._(
    background: AppColors.sidebarBackground,
    raised: AppColors.cardSurface,
    border: AppColors.borderSubtle,
    text: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    hover: Color(0x0AFFFFFF),
    tab: Color(0x2434D399), // emerald at 14%
    tabText: AppColors.primaryEmerald,
    mark: AppColors.primaryEmerald,
    tileBorder: Color(0xFF262936),
  );

  static AppSpine of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
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

/// Consistent Border Radii: the slight corners of index cards and folder
/// tabs, kept small so records read as paper rather than app tiles.
abstract final class AppRadius {
  static const double xs = 3.0;
  static const double sm = 4.0;
  static const double md = 6.0;
  static const double lg = 8.0;
  static const double card = 8.0;
  static const double xl = 12.0;
  static const double pill = 999.0;

  static const Radius radiusXs = Radius.circular(xs);
  static const Radius radiusSm = Radius.circular(sm);
  static const Radius radiusMd = Radius.circular(md);
  static const Radius radiusLg = Radius.circular(lg);
  static const Radius radiusCard = Radius.circular(card);
  static const Radius radiusXl = Radius.circular(xl);
  static const Radius radiusPill = Radius.circular(pill);

  static const BorderRadius roundedXs = BorderRadius.all(radiusXs);
  static const BorderRadius roundedSm = BorderRadius.all(radiusSm);
  static const BorderRadius roundedMd = BorderRadius.all(radiusMd);
  static const BorderRadius roundedLg = BorderRadius.all(radiusLg);
  static const BorderRadius roundedCard = BorderRadius.all(radiusCard);
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

/// Typography: one family, Atkinson Hyperlegible Next, chosen for its
/// unambiguous 0/O and 1/l/I in patient IDs, dates and dosages.
abstract final class AppType {
  static const String family = 'Atkinson Hyperlegible Next';

  /// Tabular figures so numbers line up in tables, counts and IDs.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
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
    label: 'Logbook Green',
    primaryColor: AppColors.primaryEmeraldDark,
    darkPrimaryColor: AppColors.primaryEmerald,
    secondaryColor: AppColors.primaryEmeraldDeep,
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
