import 'package:flutter/material.dart';

/// Desktop master-detail split: list on the left, detail on the right.
class ResponsiveMasterDetail extends StatelessWidget {
  final double breakpoint;
  final double masterFlex;
  final double detailFlex;
  final Widget master;
  final Widget detail;
  final bool showDetail;

  const ResponsiveMasterDetail({
    super.key,
    this.breakpoint = 1100,
    this.masterFlex = 2,
    this.detailFlex = 3,
    required this.master,
    required this.detail,
    this.showDetail = true,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < breakpoint) {
      return master;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: masterFlex.round(), child: master),
        VerticalDivider(
          width: 1,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
        Expanded(
          flex: detailFlex.round(),
          child: showDetail
              ? detail
              : _EmptyDetailPlaceholder(
                  message: 'Select an item to preview details',
                ),
        ),
      ],
    );
  }
}

class _EmptyDetailPlaceholder extends StatelessWidget {
  final String message;

  const _EmptyDetailPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
          ),
        ],
      ),
    );
  }
}

/// Sidebar + content layout for settings-style pages.
class SidebarContentLayout extends StatelessWidget {
  final double breakpoint;
  final double sidebarWidth;
  final Widget sidebar;
  final Widget content;

  const SidebarContentLayout({
    super.key,
    this.breakpoint = 900,
    this.sidebarWidth = 240,
    required this.sidebar,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < breakpoint) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sidebar,
          const Divider(height: 1),
          Expanded(child: content),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: sidebarWidth, child: sidebar),
        VerticalDivider(
          width: 1,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
        Expanded(child: content),
      ],
    );
  }
}
