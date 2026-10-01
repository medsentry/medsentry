import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_design_tokens.dart';

export '../config/app_design_tokens.dart';

/// MedSentry brand palette and base healthcare colors.
abstract final class MedSentryColors {
  // Brand Greens
  static const seed = Color(0xFF15803D);
  static const seedDark = Color(0xFF4ADE80);

  // Backgrounds
  static const lightScaffold = Color(0xFFF8FAFC); // Clean slate tint
  static const lightSurface = Color(0xFFFFFFFF);
  static const darkScaffold = Color(0xFF0B131D); // Deep medical navy/slate
  static const darkSurface = Color(0xFF111C2A); // Elevated slate surface
  static const darkSurfaceElevated = Color(0xFF182638);
  static const darkAppBar = Color(0xFF0F1A26);

  // Status/Semantic Colors
  // 🟢 Green — Normal, Active, Completed, Available
  static const statusNormal = Color(0xFF16A34A); // Green 600
  static const statusNormalDark = Color(0xFF4ADE80); // Green 400
  static const statusNormalBg = Color(0xFFDCFCE7); // Green 100

  // 🟡 Yellow/Amber — Pending, Waiting, Warning, Needs Attention
  static const statusWarning = Color(0xFFD97706); // Amber 600
  static const statusWarningDark = Color(0xFFFBBF24); // Amber 400
  static const statusWarningBg = Color(0xFFFEF3C7); // Amber 100

  // 🔴 Red — Critical, Failed, Urgent, Overdue
  static const statusCritical = Color(0xFFDC2626); // Red 600
  static const statusCriticalDark = Color(0xFFF87171); // Red 400
  static const statusCriticalBg = Color(0xFFFEE2E2); // Red 100

  // 🔵 Blue — Informational, General, In Progress
  static const statusInfo = Color(0xFF2563EB); // Blue 600
  static const statusInfoDark = Color(0xFF60A5FA); // Blue 400
  static const statusInfoBg = Color(0xFFDBEAFE); // Blue 100

  // ⚪ Gray — Inactive, Archived, Disabled, or Neutral
  static const statusNeutral = Color(0xFF64748B); // Slate 500
  static const statusNeutralDark = Color(0xFF94A3B8); // Slate 400
  static const statusNeutralBg = Color(0xFFF1F5F9); // Slate 100

  // Shades of Green (Default Brand)
  static const green900 = Color(0xFF14532D);
  static const green800 = Color(0xFF166534);
  static const green700 = Color(0xFF15803D);
  static const green600 = Color(0xFF16A34A);
  static const green500 = Color(0xFF22C55E);
  static const green400 = Color(0xFF4ADE80);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
}

/// A ThemeExtension to access standardized semantic healthcare colors anywhere in the app.
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

  // Direct semantic aliases
  Color get active => normal;
  Color get inactive => neutral;
  Color get completed => normal;
  Color get cancelled => critical;
  Color get pending => warning;
  Color get waiting => warning;
  Color get inProgress => info;

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

/// Theme Mode state notifier with SharedPreferences persistence
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'medsentry_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == 'dark') {
        state = ThemeMode.dark;
      } else if (saved == 'light') {
        state = ThemeMode.light;
      } else if (saved == 'system') {
        state = ThemeMode.system;
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {}
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Accent Theme state notifier with SharedPreferences persistence
class AccentThemeNotifier extends StateNotifier<AppAccentTheme> {
  static const _key = 'medsentry_accent_theme';

  AccentThemeNotifier() : super(AppAccentTheme.emerald) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null) {
        state = AppAccentTheme.fromId(saved);
      }
    } catch (_) {}
  }

  Future<void> setAccentTheme(AppAccentTheme theme) async {
    state = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, theme.id);
    } catch (_) {}
  }
}

final accentThemeProvider =
    StateNotifierProvider<AccentThemeNotifier, AppAccentTheme>((ref) {
  return AccentThemeNotifier();
});

/// Builds consistent MedSentry ThemeData with semantic clinical design tokens.
ThemeData buildMedSentryTheme(
  Brightness brightness, {
  AppAccentTheme accentTheme = AppAccentTheme.emerald,
}) {
  final isDark = brightness == Brightness.dark;
  final primary =
      isDark ? accentTheme.darkPrimaryColor : accentTheme.primaryColor;
  final secondary = accentTheme.secondaryColor;

  final surfaceColor =
      isDark ? MedSentryColors.darkSurface : MedSentryColors.lightSurface;
  final scaffoldColor =
      isDark ? MedSentryColors.darkScaffold : MedSentryColors.lightScaffold;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
    primary: primary,
    onPrimary: isDark ? const Color(0xFF0F172A) : Colors.white,
    primaryContainer: isDark
        ? primary.withValues(alpha: 0.22)
        : primary.withValues(alpha: 0.12),
    onPrimaryContainer: isDark ? primary : accentTheme.primaryColor,
    secondary: secondary,
    surface: surfaceColor,
    onSurface: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
    error: isDark
        ? MedSentryColors.statusCriticalDark
        : MedSentryColors.statusCritical,
    errorContainer: isDark
        ? MedSentryColors.statusCriticalDark.withValues(alpha: 0.2)
        : MedSentryColors.statusCriticalBg,
    outline: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
    outlineVariant:
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
  );

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
      backgroundColor: isDark ? MedSentryColors.darkAppBar : primary,
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
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.roundedLg,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.7),
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? MedSentryColors.darkSurfaceElevated : Colors.white,
      hintStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.5),
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: AppRadius.roundedMd,
        borderSide: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.roundedMd,
        borderSide: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.roundedMd,
        borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.roundedMd,
        borderSide: BorderSide(color: colorScheme.error, width: 1.2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, AppDimensions.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size(0, AppDimensions.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppDimensions.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
        side: BorderSide(color: colorScheme.outlineVariant),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedPill),
      side: BorderSide(color: colorScheme.outlineVariant),
      backgroundColor: surfaceColor,
      labelStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.9),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedLg),
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
      minExtendedWidth: AppDimensions.sidebarExpanded,
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
        borderRadius: AppRadius.roundedMd,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 2,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
    ),
  );
}

/// Theme provider that returns the current theme with active accent
final themeProvider = Provider<ThemeData>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  final accent = ref.watch(accentThemeProvider);
  final brightness = themeMode == ThemeMode.dark
      ? Brightness.dark
      : Brightness.light;
  return buildMedSentryTheme(brightness, accentTheme: accent);
});
