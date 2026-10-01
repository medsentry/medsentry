import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';

/// Standardized Page Header component for MedSentry EMR.
/// Communicates context, purpose, search/filters, and primary actions consistently.
class AppPageHeader extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? badge;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? searchBar;
  final Widget? filterBar;
  final EdgeInsets padding;

  const AppPageHeader({
    super.key,
    required this.title,
    this.description,
    this.badge,
    this.leading,
    this.actions,
    this.searchBar,
    this.filterBar,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              final titleContent = Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    badge!,
                  ],
                ],
              );

              final descriptionWidget = description != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  : null;

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleContent,
                    ?descriptionWidget,
                    if (actions != null && actions!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: actions!,
                      ),
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleContent,
                        ?descriptionWidget,
                      ],
                    ),
                  ),
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.lg),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!
                          .map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.sm,
                              ),
                              child: a,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              );
            },
          ),
          if (searchBar != null || filterBar != null) ...[
            const SizedBox(height: AppSpacing.md),
            ?searchBar,
            if (filterBar != null) ...[
              const SizedBox(height: AppSpacing.sm),
              filterBar!,
            ],
          ],
        ],
      ),
    );
  }
}
