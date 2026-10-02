import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/providers/theme_provider.dart';

void main() {
  group('AppDesignTokens', () {
    test('AppSpacing constants are properly scaled', () {
      expect(AppSpacing.xs, equals(4.0));
      expect(AppSpacing.sm, equals(8.0));
      expect(AppSpacing.md, equals(12.0));
      expect(AppSpacing.lg, equals(16.0));
      expect(AppSpacing.xl, equals(20.0));
      expect(AppSpacing.xxl, equals(24.0));
      expect(AppSpacing.xxxl, equals(32.0));
    });

    test(
      'AppRadius constants provide consistent healthcare rounded corners',
      () {
        expect(AppRadius.xs, equals(4.0));
        expect(AppRadius.sm, equals(6.0));
        expect(AppRadius.md, equals(10.0));
        expect(AppRadius.lg, equals(14.0));
        expect(AppRadius.xl, equals(20.0));
        expect(AppRadius.pill, equals(999.0));
      },
    );

    test('AppAccentTheme contains all 7 healthcare palettes', () {
      expect(AppAccentTheme.values.length, equals(7));

      final ids = AppAccentTheme.values.map((t) => t.id).toSet();
      expect(
        ids,
        containsAll([
          'emerald',
          'blue',
          'teal',
          'indigo',
          'purple',
          'amber',
          'rose',
        ]),
      );

      expect(AppAccentTheme.fromId('blue'), equals(AppAccentTheme.blue));
      expect(AppAccentTheme.fromId('unknown'), equals(AppAccentTheme.emerald));
    });

    test('SemanticColors ThemeExtension has proper status color tokens', () {
      const colors = SemanticColors(
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
      expect(colors.normal, equals(MedSentryColors.statusNormal));
      expect(colors.warning, equals(MedSentryColors.statusWarning));
      expect(colors.critical, equals(MedSentryColors.statusCritical));
      expect(colors.info, equals(MedSentryColors.statusInfo));
      expect(colors.neutral, equals(MedSentryColors.statusNeutral));

      // Test semantic aliases
      expect(colors.active, equals(colors.normal));
      expect(colors.completed, equals(colors.normal));
      expect(colors.pending, equals(colors.warning));
      expect(colors.waiting, equals(colors.warning));
      expect(colors.cancelled, equals(colors.critical));
      expect(colors.inProgress, equals(colors.info));
      expect(colors.inactive, equals(colors.neutral));
    });

    test(
      'buildMedSentryTheme produces valid light and dark ThemeData with accents',
      () {
        final lightTheme = buildMedSentryTheme(
          Brightness.light,
          accentTheme: AppAccentTheme.teal,
        );
        expect(lightTheme.brightness, equals(Brightness.light));
        expect(
          lightTheme.colorScheme.primary,
          equals(AppAccentTheme.teal.primaryColor),
        );

        final darkTheme = buildMedSentryTheme(
          Brightness.dark,
          accentTheme: AppAccentTheme.indigo,
        );
        expect(darkTheme.brightness, equals(Brightness.dark));
        expect(
          darkTheme.colorScheme.primary,
          equals(AppAccentTheme.indigo.darkPrimaryColor),
        );
      },
    );
  });
}
