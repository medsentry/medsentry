import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_design_tokens.dart';

export '../config/app_design_tokens.dart';

/// Legacy MedSentry brand palette aliased to [AppColors] for backward compatibility.
abstract final class MedSentryColors {
  // Brand Greens
  static const seed = AppColors.primaryEmerald;
  static const seedDark = AppColors.primaryEmerald;

  // Backgrounds
  static const lightScaffold = AppColors.lightAppBackground;
  static const lightSurface = AppColors.lightCardSurface;
  static const darkScaffold = AppColors.appBackground; // #080909
  static const darkSurface = AppColors.cardSurface; // #111214
  static const darkSurfaceElevated = AppColors.elevatedSurface; // #191A1C
  static const darkAppBar = AppColors.sidebarBackground; // #111214

  // Status/Semantic Colors
  static const statusNormal = AppColors.success;
  static const statusNormalDark = AppColors.success;
  static const statusNormalBg = AppColors.successBg;

  static const statusWarning = AppColors.pending;
  static const statusWarningDark = AppColors.pending;
  static const statusWarningBg = AppColors.pendingBg;

  static const statusCritical = AppColors.critical;
  static const statusCriticalDark = AppColors.critical;
  static const statusCriticalBg = AppColors.criticalBg;

  static const statusInfo = AppColors.info;
  static const statusInfoDark = AppColors.info;
  static const statusInfoBg = AppColors.infoBg;

  static const statusNeutral = AppColors.neutral;
  static const statusNeutralDark = AppColors.neutral;
  static const statusNeutralBg = AppColors.neutralBg;

  static const green900 = AppColors.primaryEmeraldDeep;
  static const green800 = Color(0xFF166534);
  static const green700 = AppColors.primaryEmeraldDark;
  static const green600 = Color(0xFF16A34A);
  static const green500 = Color(0xFF22C55E);
  static const green400 = AppColors.primaryEmerald;
  static const emerald600 = AppColors.primaryEmeraldDark;
  static const emerald700 = AppColors.primaryEmeraldDeep;
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
  final Color analytical;
  final Color analyticalBg;

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
    this.analytical = AppColors.analytical,
    this.analyticalBg = AppColors.analyticalBg,
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
    Color? analytical,
    Color? analyticalBg,
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
      analytical: analytical ?? this.analytical,
      analyticalBg: analyticalBg ?? this.analyticalBg,
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
      analytical: Color.lerp(analytical, other.analytical, t)!,
      analyticalBg: Color.lerp(analyticalBg, other.analyticalBg, t)!,
    );
  }
}

/// Theme Mode state notifier with SharedPreferences persistence.
/// Defaults to [ThemeMode.dark] to embody the premium dark healthcare foundation.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'medsentry_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.dark) {
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

/// Accent Theme state notifier with SharedPreferences persistence.
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

  final scaffoldColor =
      isDark ? AppColors.appBackground : AppColors.lightAppBackground;
  final surfaceColor =
      isDark ? AppColors.cardSurface : AppColors.lightCardSurface;
  final elevatedSurfaceColor =
      isDark ? AppColors.elevatedSurface : AppColors.lightElevatedSurface;
  final borderColor = isDark ? AppColors.border : AppColors.lightBorder;
  final borderSubtleColor =
      isDark ? AppColors.borderSubtle : AppColors.lightBorderSubtle;
  final textPrimaryColor =
      isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  final textSecondaryColor =
      isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: isDark ? AppColors.textOnEmerald : Colors.white,
    primaryContainer: isDark
        ? primary.withValues(alpha: 0.18)
        : primary.withValues(alpha: 0.12),
    onPrimaryContainer: isDark ? primary : accentTheme.primaryColor,
    secondary: secondary,
    onSecondary: Colors.white,
    surface: surfaceColor,
    onSurface: textPrimaryColor,
    error: isDark ? AppColors.critical : const Color(0xFFDC2626),
    onError: Colors.white,
    errorContainer: isDark
        ? AppColors.critical.withValues(alpha: 0.18)
        : const Color(0xFFFEE2E2),
    onErrorContainer: isDark ? AppColors.critical : const Color(0xFF991B1B),
    outline: borderColor,
    outlineVariant: borderSubtleColor,
  );

  final semanticColors = SemanticColors(
    normal: isDark ? AppColors.success : const Color(0xFF16A34A),
    normalBg: isDark ? AppColors.successBg : const Color(0xFFDCFCE7),
    warning: isDark ? AppColors.pending : const Color(0xFFD97706),
    warningBg: isDark ? AppColors.pendingBg : const Color(0xFFFEF3C7),
    critical: isDark ? AppColors.critical : const Color(0xFFDC2626),
    criticalBg: isDark ? AppColors.criticalBg : const Color(0xFFFEE2E2),
    info: isDark ? AppColors.info : const Color(0xFF2563EB),
    infoBg: isDark ? AppColors.infoBg : const Color(0xFFDBEAFE),
    neutral: isDark ? AppColors.neutral : const Color(0xFF64748B),
    neutralBg: isDark ? AppColors.neutralBg : const Color(0xFFF1F5F9),
    analytical: isDark ? AppColors.analytical : const Color(0xFF7C3AED),
    analyticalBg: isDark ? AppColors.analyticalBg : const Color(0xFFEDE9FE),
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
      backgroundColor: isDark ? AppColors.sidebarBackground : Colors.white,
      foregroundColor: textPrimaryColor,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimaryColor,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.roundedCard,
        side: BorderSide(
          color: borderColor,
          width: AppColors.borderWidth,
        ),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: borderSubtleColor,
      thickness: AppColors.borderWidth,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.inputSurface : AppColors.lightInputSurface,
      hintStyle: TextStyle(
        color: textSecondaryColor.withValues(alpha: 0.6),
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: AppRadius.roundedSm,
        borderSide: BorderSide(
          color: borderColor,
          width: AppColors.borderWidth,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.roundedSm,
        borderSide: BorderSide(
          color: borderColor,
          width: AppColors.borderWidth,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.roundedSm,
        borderSide: BorderSide(
          color: primary,
          width: AppColors.borderWidthActive,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.roundedSm,
        borderSide: BorderSide(
          color: colorScheme.error,
          width: AppColors.borderWidth,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.roundedSm,
        borderSide: BorderSide(
          color: colorScheme.error,
          width: AppColors.borderWidthActive,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size(0, AppDimensions.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: -0.1,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size(0, AppDimensions.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: -0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppDimensions.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        foregroundColor: textPrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
        side: BorderSide(color: borderColor, width: AppColors.borderWidth),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: -0.1,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedSm),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: -0.1,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedPill),
      side: BorderSide(color: borderColor, width: AppColors.borderWidth),
      backgroundColor: elevatedSurfaceColor,
      labelStyle: TextStyle(
        color: textPrimaryColor,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: elevatedSurfaceColor,
      contentTextStyle: TextStyle(color: textPrimaryColor, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.roundedSm,
        side: BorderSide(color: borderColor, width: AppColors.borderWidth),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor:
          isDark ? AppColors.modalSurface : AppColors.lightModalSurface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.roundedLg,
        side: BorderSide(color: borderColor, width: AppColors.borderWidth),
      ),
      titleTextStyle: TextStyle(
        color: textPrimaryColor,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      contentTextStyle: TextStyle(
        color: textSecondaryColor,
        fontSize: 14,
        height: 1.5,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor:
          isDark ? AppColors.sidebarBackground : Colors.white,
      elevation: 0,
      minExtendedWidth: AppDimensions.sidebarExpanded,
      selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 20),
      unselectedIconTheme: IconThemeData(
        color: textSecondaryColor,
        size: 20,
      ),
      selectedLabelTextStyle: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: textSecondaryColor,
        fontSize: 13,
      ),
      indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: AppRadius.roundedSm,
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowHeight: AppDimensions.tableHeaderHeight,
      dataRowMinHeight: AppDimensions.tableRowHeight,
      dataRowMaxHeight: AppDimensions.tableRowHeight,
      headingTextStyle: TextStyle(
        color: textSecondaryColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      dataTextStyle: TextStyle(
        color: textPrimaryColor,
        fontSize: 13,
      ),
      dividerThickness: 1,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: elevatedSurfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.roundedMd,
        side: BorderSide(color: borderColor, width: AppColors.borderWidth),
      ),
      textStyle: TextStyle(
        color: textPrimaryColor,
        fontSize: 13,
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
