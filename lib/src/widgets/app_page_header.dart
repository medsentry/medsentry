import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';

/// Item in a breadcrumb trail
class AppBreadcrumbItem {
  final String label;
  final VoidCallback? onTap;

  const AppBreadcrumbItem({required this.label, this.onTap});
}

/// Standardized Page Header component for MedSentry EMR.
/// Communicates breadcrumbs, context, purpose, search/filters, and primary/secondary actions consistently.
class AppPageHeader extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? badge;
  final Widget? leading;
  final List<AppBreadcrumbItem>? breadcrumbs;
  final List<Widget>? actions;
  final Widget? primaryAction;
  final Widget? searchBar;
  final Widget? filterBar;
  final Widget? toolbar;
  final EdgeInsets padding;

  const AppPageHeader({
    super.key,
    required this.title,
    this.description,
    this.badge,
    this.leading,
    this.breadcrumbs,
    this.actions,
    this.primaryAction,
    this.searchBar,
    this.filterBar,
    this.toolbar,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final allActions = <Widget>[
      ...?actions,
      ?primaryAction,
    ];

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Breadcrumbs
          if (breadcrumbs != null && breadcrumbs!.isNotEmpty) ...[
            _buildBreadcrumbs(context),
            const SizedBox(height: AppSpacing.xs),
          ],

          // 2. Title, Description, and Actions
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
                        color: isDark ? AppColors.textPrimary : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: AppSpacing.sm),
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
                          color: isDark ? AppColors.textSecondary : colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.4,
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
                    if (allActions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: allActions,
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
                  if (allActions.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.lg),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: allActions
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

          // 3. Optional Toolbar / Search / Filters
          if (toolbar != null || searchBar != null || filterBar != null) ...[
            const SizedBox(height: AppSpacing.md),
            ?toolbar,
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

  Widget _buildBreadcrumbs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = breadcrumbs!;
    final breadcrumbWidgets = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;

      if (item.onTap != null && !isLast) {
        breadcrumbWidgets.add(
          InkWell(
            onTap: item.onTap,
            borderRadius: AppRadius.roundedXs,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textSecondary : Colors.black54,
                ),
              ),
            ),
          ),
        );
      } else {
        breadcrumbWidgets.add(
          Text(
            item.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
              color: isLast
                  ? (isDark ? AppColors.textPrimary : Colors.black87)
                  : (isDark ? AppColors.textSecondary : Colors.black54),
            ),
          ),
        );
      }

      if (!isLast) {
        breadcrumbWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '/',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textMuted : Colors.black38,
              ),
            ),
          ),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: breadcrumbWidgets,
    );
  }
}
