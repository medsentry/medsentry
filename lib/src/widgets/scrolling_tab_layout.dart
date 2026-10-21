import 'package:flutter/material.dart';

/// A tabbed page that scrolls as one: everything above the tabs and the tab
/// bar itself scroll away with the open tab's content, instead of staying
/// fixed and squeezing the tab into a small scrolling box.
///
/// Each tab's own scroll view (ListView, SingleChildScrollView) must use the
/// default primary controller so it hands its scrolling to the page. A tab
/// with two scroll views side by side should merge them into one.
class ScrollingTabLayout extends StatelessWidget {
  const ScrollingTabLayout({
    super.key,
    this.header = const [],
    required this.tabBar,
    required this.tabView,
    this.gap = 12,
    this.unboundedHeight = 760,
  });

  /// Widgets stacked above the tab bar, including any spacing between them.
  final List<Widget> header;
  final Widget tabBar;

  /// Usually a [TabBarView].
  final Widget tabView;

  /// Space between the tab bar and the tab content.
  final double gap;

  /// Tab height used when a parent gives no height limit, such as when the
  /// page is placed inside another scroll view.
  final double unboundedHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxHeight.isFinite) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...header,
              tabBar,
              SizedBox(height: gap),
              SizedBox(height: unboundedHeight, child: tabView),
            ],
          );
        }

        return NestedScrollView(
          headerSliverBuilder: (context, _) => [
            for (final widget in header) SliverToBoxAdapter(child: widget),
            SliverToBoxAdapter(child: tabBar),
            SliverToBoxAdapter(child: SizedBox(height: gap)),
          ],
          body: tabView,
        );
      },
    );
  }
}
