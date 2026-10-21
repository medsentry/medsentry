import 'package:flutter/material.dart';

import '../config/app_design_tokens.dart';

/// Shared colours for the flat app-screen style used across MedSentry's
/// working screens: leaf-paper (or night-shift) panels, a 1px rule-green
/// border, a 6px radius, and bottle green kept for data and the one primary
/// action.
class ScreenTokens {
  const ScreenTokens._({
    required this.isDark,
    required this.surface,
    required this.raised,
    required this.border,
    required this.control,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentSubtle,
  });

  final bool isDark;
  final Color surface;
  final Color raised;
  final Color border;
  final Color control;
  final Color text;
  final Color muted;

  /// The one hue: data marks, the active state and the primary action.
  final Color accent;
  final Color onAccent;
  final Color accentSubtle;

  static const radius = BorderRadius.all(Radius.circular(AppRadius.md));

  static const _light = ScreenTokens._(
    isDark: false,
    surface: AppColors.lightCardSurface,
    raised: AppColors.lightElevatedSurface,
    border: AppColors.lightBorder,
    control: AppColors.lightBorderActive,
    text: AppColors.lightTextPrimary,
    muted: AppColors.lightTextSecondary,
    accent: AppColors.primaryEmeraldDark,
    onAccent: Colors.white,
    accentSubtle: Color(0x141D5C45),
  );

  static const _dark = ScreenTokens._(
    isDark: true,
    surface: AppColors.cardSurface,
    raised: AppColors.elevatedSurface,
    border: AppColors.border,
    control: AppColors.borderActive,
    text: AppColors.textPrimary,
    muted: Color(0xFFA1A5AE),
    accent: AppColors.primaryEmerald,
    onAccent: AppColors.textOnEmerald,
    accentSubtle: AppColors.primaryEmeraldSubtle,
  );

  static ScreenTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  BoxDecoration get panel => BoxDecoration(
    color: surface,
    borderRadius: radius,
    border: Border.all(color: border),
  );

  ButtonStyle get outlinedButton => OutlinedButton.styleFrom(
    foregroundColor: text,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: const Size(0, 36),
    shape: const RoundedRectangleBorder(borderRadius: radius),
    side: BorderSide(color: control),
    textStyle: const TextStyle(
      fontFamily: AppType.family,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  );

  ButtonStyle get filledButton => FilledButton.styleFrom(
    backgroundColor: accent,
    foregroundColor: onAccent,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    minimumSize: const Size(0, 36),
    shape: const RoundedRectangleBorder(borderRadius: radius),
    textStyle: const TextStyle(
      fontFamily: AppType.family,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// The title row every working screen opens with: a plain grey icon, the
/// screen's name as its heading, one grey line about the data, and the
/// screen's real actions on the right (wrapping under the title when narrow).
/// It is ruled off from the page below by the ledger's double red line.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = ScreenTokens.of(context);

    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(icon, size: 22, color: t.muted),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.5,
                    color: t.text,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 15, color: t.muted, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (actions.isEmpty) return heading;
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 16),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
        },
      ),
    );

    return Container(
      decoration: t.panel,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          body,
          LedgerRule(isDark: t.isDark),
        ],
      ),
    );
  }
}

/// The double red line printed under the header of a columnar ledger pad.
/// MedSentry's one recurring mark in light mode: it closes each screen
/// header and table header, and is used nowhere else. Dark mode omits it.
class LedgerRule extends StatelessWidget {
  const LedgerRule({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (isDark) return const SizedBox.shrink();
    final color = AppColors.ledgerRule(isDark);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 1, color: color),
        const SizedBox(height: 2),
        Container(height: 1, color: color),
      ],
    );
  }
}

class Metric {
  const Metric({
    required this.label,
    required this.value,
    this.note,
    this.onTap,
    this.noteIsAlert = false,
  });

  final String label;
  final String value;

  /// One grey line under the value: what it counts or its baseline.
  final String? note;
  final VoidCallback? onTap;

  /// Sets the note in the negative colour, for a figure that needs action.
  final bool noteIsAlert;
}

/// Headline figures as one bordered container split by 1px dividers, label
/// over value, no icons. Becomes a two-column grid on narrow widths.
class MetricStrip extends StatelessWidget {
  const MetricStrip({super.key, required this.metrics});

  final List<Metric> metrics;

  @override
  Widget build(BuildContext context) {
    final t = ScreenTokens.of(context);

    return Container(
      decoration: t.panel,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final perRow = constraints.maxWidth < 640 && metrics.length > 2
              ? 2
              : metrics.length;
          final rows = <Widget>[];
          for (var start = 0; start < metrics.length; start += perRow) {
            final slice = metrics.skip(start).take(perRow).toList();
            if (rows.isNotEmpty) {
              rows.add(Divider(height: 1, thickness: 1, color: t.border));
            }
            rows.add(
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < slice.length; i++) ...[
                      if (i > 0)
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: t.border,
                        ),
                      Expanded(
                        // An odd last cell spans the row instead of leaving
                        // an empty half beside it.
                        flex: slice.length < perRow ? perRow : 1,
                        child: _MetricCell(
                          metric: slice[i],
                          tokens: t,
                          compact: perRow > 1 && constraints.maxWidth < 640,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return Column(mainAxisSize: MainAxisSize.min, children: rows);
        },
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.metric,
    required this.tokens,
    this.compact = false,
  });

  final Metric metric;
  final ScreenTokens tokens;

  /// Two cells share a phone-width row, so the figure is set smaller.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: t.muted,
                  ),
                ),
              ),
              if (metric.onTap != null)
                Icon(Icons.chevron_right_rounded, size: 16, color: t.muted),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            metric.value,
            style: TextStyle(
              fontSize: compact ? 20 : 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: t.text,
              fontFeatures: AppType.tabular,
            ),
          ),
          if (metric.note != null) ...[
            const SizedBox(height: 4),
            Text(
              metric.note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: metric.noteIsAlert
                    ? (t.isDark ? AppColors.critical : const Color(0xFFA12C22))
                    : t.muted,
              ),
            ),
          ],
        ],
      ),
    );

    if (metric.onTap == null) return content;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: metric.onTap, child: content),
    );
  }
}

/// A list or table block with nothing in it yet: the block keeps its frame and
/// says in one sentence what will appear there.
class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.icon,
    required this.message,
    this.detail,
    this.action,
  });

  final IconData icon;
  final String message;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = ScreenTokens.of(context);
    return Container(
      decoration: t.panel,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: t.muted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: t.text,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: t.muted, height: 1.4),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

/// One bordered panel holding a list of rows split by 1px rules, instead of a
/// stack of identical cards. Ink from row taps shows on the panel.
class RowsPanel extends StatelessWidget {
  const RowsPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = ScreenTokens.of(context);
    return Container(
      decoration: t.panel,
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: t.border),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
