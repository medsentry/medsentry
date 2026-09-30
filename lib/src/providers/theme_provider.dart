import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// MedSentry brand palette and semantic colors.
abstract final class MedSentryColors {
  // Brand Greens
  static const seed = Color(0xFF15803D);
  static const seedDark = Color(0xFF4ADE80);

  // Backgrounds
  static const lightScaffold = Color(0xFFF0FDF4); // Very light green tint
  static const lightSurface = Color(0xFFFFFFFF);
  static const darkScaffold = Color(0xFF071510);
  static const darkSurface = Color(0xFF12261A);
  static const darkAppBar = Color(0xFF14532D);

  // Status/Semantic Colors (As requested by user)
  // 🟢 Green — Normal, Active, Completed, Available
  static const statusNormal = Color(0xFF22C55E); // Green 500
  static const statusNormalDark = Color(0xFF15803D); // Green 700
  static const statusNormalBg = Color(0xFFDCFCE7); // Green 100

  // 🟡 Yellow/Amber — Pending, Waiting, Warning, Needs Attention
  static const statusWarning = Color(0xFFF59E0B); // Amber 500
  static const statusWarningDark = Color(0xFFB45309); // Amber 700
  static const statusWarningBg = Color(0xFFFEF3C7); // Amber 100

  // 🔴 Red — Critical, Failed, Urgent, Overdue
  static const statusCritical = Color(0xFFEF4444); // Red 500
  static const statusCriticalDark = Color(0xFFB91C1C); // Red 700
  static const statusCriticalBg = Color(0xFFFEE2E2); // Red 100

  // 🔵 Blue — Informational, General, In Progress
  static const statusInfo = Color(0xFF3B82F6); // Blue 500
  static const statusInfoDark = Color(0xFF1D4ED8); // Blue 700
  static const statusInfoBg = Color(0xFFDBEAFE); // Blue 100

  // ⚪ Gray — Inactive, Archived, Disabled, or Neutral
  static const statusNeutral = Color(0xFF6B7280); // Gray 500
  static const statusNeutralDark = Color(0xFF374151); // Gray 700
  static const statusNeutralBg = Color(0xFFF3F4F6); // Gray 100

  // Shades of Green (Brand)
  static const green900 = Color(0xFF14532D);
  static const green800 = Color(0xFF166534);
  static const green700 = Color(0xFF15803D);
  static const green600 = Color(0xFF16A34A);
  static const green500 = Color(0xFF22C55E);
  static const green400 = Color(0xFF4ADE80);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
}

/// A ThemeExtension to easily access our semantic colors anywhere in the app.
class SemanticColors extends ThemeExtension<SemanticColors> {
  final Color normal;
  final Color normalBg;
  final Color warning;
  final Color warningBg;
  final Color critical;
  final Color criticalBg;
  final Color info;
  final Color infoBg;
  final Color neutral;
  final Color neutralBg;

  const SemanticColors({
    required this.normal,
    required this.normalBg,
    required this.warning,
    required this.warningBg,
    required this.critical,
    required this.criticalBg,
    required this.info,
    required this.infoBg,
    required this.neutral,
    required this.neutralBg,
  });

  @override
  ThemeExtension<SemanticColors> copyWith({
    Color? normal,
    Color? normalBg,
    Color? warning,
    Color? warningBg,
    Color? critical,
    Color? criticalBg,
    Color? info,
    Color? infoBg,
    Color? neutral,
    Color? neutralBg,
  }) {
    return SemanticColors(
      normal: normal ?? this.normal,
      normalBg: normalBg ?? this.normalBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      critical: critical ?? this.critical,
      criticalBg: criticalBg ?? this.criticalBg,
      info: info ?? this.info,
      infoBg: infoBg ?? this.infoBg,
      neutral: neutral ?? this.neutral,
      neutralBg: neutralBg ?? this.neutralBg,
    );
  }

  @override
  ThemeExtension<SemanticColors> lerp(
    covariant ThemeExtension<SemanticColors>? other,
    double t,
  ) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      normal: Color.lerp(normal, other.normal, t)!,
      normalBg: Color.lerp(normalBg, other.normalBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      criticalBg: Color.lerp(criticalBg, other.criticalBg, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      neutralBg: Color.lerp(neutralBg, other.neutralBg, t)!,
    );
  }
}

/// Theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

ThemeData buildMedSentryTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final seed = isDark ? MedSentryColors.seedDark : MedSentryColors.seed;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    primary: isDark ? MedSentryColors.green400 : MedSentryColors.green700,
    onPrimary: isDark ? MedSentryColors.green900 : Colors.white,
    primaryContainer: isDark
        ? MedSentryColors.green900.withValues(alpha: 0.55)
        : MedSentryColors.lightScaffold,
    onPrimaryContainer: isDark
        ? MedSentryColors.green400
        : MedSentryColors.green800,
    secondary: isDark ? MedSentryColors.emerald600 : MedSentryColors.emerald700,
    surface: isDark
        ? MedSentryColors.darkSurface
        : MedSentryColors.lightSurface,
  );

  final surfaceColor = isDark
      ? MedSentryColors.darkSurface
      : MedSentryColors.lightSurface;
  final scaffoldColor = isDark
      ? MedSentryColors.darkScaffold
      : MedSentryColors.lightScaffold;

  final semanticColors = SemanticColors(
    normal: isDark
        ? MedSentryColors.statusNormalDark
        : MedSentryColors.statusNormal,
    normalBg: isDark
        ? MedSentryColors.statusNormalDark.withValues(alpha: 0.2)
        : MedSentryColors.statusNormalBg,
    warning: isDark
        ? MedSentryColors.statusWarningDark
        : MedSentryColors.statusWarning,
    warningBg: isDark
        ? MedSentryColors.statusWarningDark.withValues(alpha: 0.2)
        : MedSentryColors.statusWarningBg,
    critical: isDark
        ? MedSentryColors.statusCriticalDark
        : MedSentryColors.statusCritical,
    criticalBg: isDark
        ? MedSentryColors.statusCriticalDark.withValues(alpha: 0.2)
        : MedSentryColors.statusCriticalBg,
    info: isDark ? MedSentryColors.statusInfoDark : MedSentryColors.statusInfo,
    infoBg: isDark
        ? MedSentryColors.statusInfoDark.withValues(alpha: 0.2)
        : MedSentryColors.statusInfoBg,
    neutral: isDark
        ? MedSentryColors.statusNeutralDark
        : MedSentryColors.statusNeutral,
    neutralBg: isDark
        ? MedSentryColors.statusNeutralDark.withValues(alpha: 0.2)
        : MedSentryColors.statusNeutralBg,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    primaryColor: colorScheme.primary,
    extensions: [semanticColors],
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: isDark
          ? MedSentryColors.darkAppBar
          : colorScheme.primary,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(0),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline.withValues(alpha: 0.2),
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1A2E22) : Colors.white,
      hintStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.55),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colorScheme.error, width: 1.2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.35)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.25)),
      backgroundColor: surfaceColor,
      labelStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.9),
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.8),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surfaceColor,
      elevation: 0,
      minExtendedWidth: 220,
      selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 22),
      unselectedIconTheme: IconThemeData(
        color: colorScheme.onSurface.withValues(alpha: 0.7),
        size: 21,
      ),
      selectedLabelTextStyle: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.75),
      ),
      indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
    ),
  );
}

/// Theme provider that returns the current theme
final themeProvider = Provider<ThemeData>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  final brightness = themeMode == ThemeMode.dark
      ? Brightness.dark
      : Brightness.light;
  return buildMedSentryTheme(brightness);
});
