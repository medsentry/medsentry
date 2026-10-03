import 'package:flutter/material.dart';

/// Screen classification based on standard responsive design breakpoints.
enum ResponsiveScreenType { mobile, tablet, desktop, ultraWide }

/// Standard MedSentry responsive design breakpoints.
class ResponsiveBreakpoints {
  const ResponsiveBreakpoints._();

  /// Mobile breakpoint: width < 600 dp (smartphones, small foldables).
  static const double mobile = 600.0;

  /// Tablet breakpoint: 600 dp <= width <= 1024 dp (iPads, Android tablets, portrait laptop windows).
  static const double tablet = 1024.0;

  /// Desktop breakpoint: 1024 dp < width <= 1600 dp (laptops, standard monitors).
  static const double desktop = 1600.0;

  /// Compact height breakpoint: height < 500 dp (landscape smartphones, active virtual keyboards).
  static const double compactHeight = 500.0;

  /// Short height breakpoint: height < 650 dp (small laptops, multi-window split screens).
  static const double shortHeight = 650.0;

  /// Minimum touch target size according to Material 3 & WCAG 2.1 AA.
  static const double minTouchTargetSize = 48.0;

  /// Classify screen type based on width (and optional height) in dp.
  static ResponsiveScreenType getScreenType(double width, [double? height]) {
    if (width < mobile ||
        (height != null && height < compactHeight && width < tablet)) {
      return ResponsiveScreenType.mobile;
    } else if (width < tablet) {
      return ResponsiveScreenType.tablet;
    } else if (width < desktop) {
      return ResponsiveScreenType.desktop;
    } else {
      return ResponsiveScreenType.ultraWide;
    }
  }

  /// Helper to check if current context is Mobile (< 600px width, or landscape phone with compact height).
  static bool isMobile(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width < mobile ||
        (size.height < compactHeight && size.width < tablet);
  }

  /// Helper to check if current context is Tablet (600px - 1024px width, with sufficient vertical height).
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return !isMobile(context) && size.width <= tablet;
  }

  /// Helper to check if current context is Desktop (> 1024px and <= 1600px).
  static bool isDesktop(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return !isMobile(context) &&
        !isTablet(context) &&
        size.width <= desktop;
  }

  /// Helper to check if current context is Ultra-Wide (> 1600px).
  static bool isUltraWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width > desktop;

  /// Check if the viewport height is compact (< 500px, e.g. landscape phone or active keyboard).
  static bool isCompactHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height < compactHeight;

  /// Check if the viewport height is short (< 650px).
  static bool isShortHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height < shortHeight;

  /// Check if the device is currently in landscape orientation.
  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height;
  }

  /// Check if the device is currently in portrait orientation.
  static bool isPortrait(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.height >= size.width;
  }

  /// Get standard grid columns count based on width.
  static int getGridColumns(
    double width, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 4,
  }) {
    if (width < ResponsiveBreakpoints.mobile) return mobile;
    if (width < ResponsiveBreakpoints.tablet) return tablet;
    return desktop;
  }
}

/// A comprehensive, multi-breakpoint responsive layout utility.
///
/// Supports declarative widget switching based on local constraints ([LayoutBuilder])
/// or global window dimensions ([MediaQuery]), with static evaluation helpers and context extensions.
class ResponsiveLayout extends StatelessWidget {
  /// Widget displayed on mobile viewports (< 600px).
  final Widget mobile;

  /// Optional widget displayed on tablet viewports (600px - 1024px).
  /// Falls back to [desktop] if provided, otherwise [mobile].
  final Widget? tablet;

  /// Widget displayed on desktop viewports (> 1024px).
  final Widget desktop;

  /// Optional widget displayed on ultra-wide viewports (> 1600px).
  /// Falls back to [desktop].
  final Widget? ultraWide;

  /// When true, evaluation is based on parent [BoxConstraints] via [LayoutBuilder].
  /// When false, evaluation is based on the global window width via [MediaQuery].
  final bool useConstraints;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
    this.ultraWide,
    this.useConstraints = true,
  });

  /// Check if the current context or width is Mobile (< 600px width, or landscape phone with compact height).
  static bool isMobile(BuildContext context) =>
      ResponsiveBreakpoints.isMobile(context);

  /// Check if the current context or width is Tablet (600px - 1024px).
  static bool isTablet(BuildContext context) =>
      ResponsiveBreakpoints.isTablet(context);

  /// Check if the current context or width is Desktop (> 1024px).
  static bool isDesktop(BuildContext context) =>
      ResponsiveBreakpoints.isDesktop(context);

  /// Check if the current context or width is Ultra-Wide (> 1600px).
  static bool isUltraWide(BuildContext context) =>
      ResponsiveBreakpoints.isUltraWide(context);

  /// Check if current context has compact height (< 500px).
  static bool isCompactHeight(BuildContext context) =>
      ResponsiveBreakpoints.isCompactHeight(context);

  /// Check if current context has short height (< 650px).
  static bool isShortHeight(BuildContext context) =>
      ResponsiveBreakpoints.isShortHeight(context);

  /// Check if current context is landscape orientation.
  static bool isLandscape(BuildContext context) =>
      ResponsiveBreakpoints.isLandscape(context);

  /// Check if current context is portrait orientation.
  static bool isPortrait(BuildContext context) =>
      ResponsiveBreakpoints.isPortrait(context);

  /// Resolve current [ResponsiveScreenType] from [BuildContext].
  static ResponsiveScreenType getScreenType(BuildContext context) {
    if (isMobile(context)) {
      return ResponsiveScreenType.mobile;
    } else if (isTablet(context)) {
      return ResponsiveScreenType.tablet;
    } else if (isDesktop(context)) {
      return ResponsiveScreenType.desktop;
    } else {
      return ResponsiveScreenType.ultraWide;
    }
  }

  /// Resolve [ResponsiveScreenType] from raw pixel width and optional height.
  static ResponsiveScreenType getScreenTypeFromWidth(
    double width, [
    double? height,
  ]) {
    return ResponsiveBreakpoints.getScreenType(width, height);
  }

  /// Returns a responsive value based on the active screen type.
  static T value<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
    T? ultraWide,
  }) {
    final type = getScreenType(context);
    switch (type) {
      case ResponsiveScreenType.mobile:
        return mobile;
      case ResponsiveScreenType.tablet:
        return tablet ?? desktop ?? mobile;
      case ResponsiveScreenType.desktop:
        return desktop ?? tablet ?? mobile;
      case ResponsiveScreenType.ultraWide:
        return ultraWide ?? desktop ?? tablet ?? mobile;
    }
  }

  /// Calculate adaptive grid columns count based on viewport width.
  static int gridColumns(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 4,
    int? ultraWide,
  }) {
    return value<int>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      ultraWide: ultraWide ?? (desktop + 1),
    );
  }

  /// Calculate adaptive horizontal padding for pages.
  static EdgeInsets pagePadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: value<double>(
        context: context,
        mobile: 16.0,
        tablet: 24.0,
        desktop: 32.0,
        ultraWide: 48.0,
      ),
      vertical: value<double>(
        context: context,
        mobile: 16.0,
        tablet: 20.0,
        desktop: 24.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (useConstraints) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final type = getScreenTypeFromWidth(
            constraints.maxWidth,
            constraints.hasBoundedHeight ? constraints.maxHeight : null,
          );
          switch (type) {
            case ResponsiveScreenType.mobile:
              return mobile;
            case ResponsiveScreenType.tablet:
              return tablet ?? desktop;
            case ResponsiveScreenType.desktop:
              return desktop;
            case ResponsiveScreenType.ultraWide:
              return ultraWide ?? desktop;
          }
        },
      );
    }

    final type = getScreenType(context);
    switch (type) {
      case ResponsiveScreenType.mobile:
        return mobile;
      case ResponsiveScreenType.tablet:
        return tablet ?? desktop;
      case ResponsiveScreenType.desktop:
        return desktop;
      case ResponsiveScreenType.ultraWide:
        return ultraWide ?? desktop;
    }
  }
}

/// A builder widget providing constraints and [ResponsiveScreenType].
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    BoxConstraints constraints,
    ResponsiveScreenType screenType,
  )
  builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = ResponsiveLayout.getScreenTypeFromWidth(
          constraints.maxWidth,
        );
        return builder(context, constraints, screenType);
      },
    );
  }
}

/// Enforces maximum readable width on ultra-wide monitors and centers content.
class ResponsiveContentContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContentContainer({
    super.key,
    required this.child,
    this.maxWidth = 1600.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? ResponsiveLayout.pagePadding(context),
          child: child,
        ),
      ),
    );
  }
}

/// Wraps interactive elements to guarantee minimum 48x48dp touch targets on touch devices,
/// while providing desktop mouse hover pointer affordances.
class AdaptiveInteractiveTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final MouseCursor cursor;
  final BorderRadius? borderRadius;
  final bool enforceTouchTarget;

  const AdaptiveInteractiveTarget({
    super.key,
    required this.child,
    this.onTap,
    this.tooltip,
    this.cursor = SystemMouseCursors.click,
    this.borderRadius,
    this.enforceTouchTarget = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget result = InkWell(
      onTap: onTap,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      mouseCursor: cursor,
      child: child,
    );

    if (enforceTouchTarget) {
      result = ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: ResponsiveBreakpoints.minTouchTargetSize,
          minHeight: ResponsiveBreakpoints.minTouchTargetSize,
        ),
        child: Center(widthFactor: 1.0, heightFactor: 1.0, child: result),
      );
    }

    if (tooltip != null) {
      result = Tooltip(message: tooltip!, child: result);
    }

    return result;
  }
}
