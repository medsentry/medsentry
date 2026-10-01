import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_design_tokens.dart';

/// Clean inline or centered loading state for MedSentry EMR.
class LoadingState extends StatelessWidget {
  final String message;
  final bool inline;
  final double size;

  const LoadingState({
    super.key,
    this.message = 'Loading...',
    this.inline = false,
    this.size = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicator = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
      ),
    );

    if (inline) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            indicator,
            if (message.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.md),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            indicator,
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton loader for tables, lists, and patient cards
class AppSkeletonLoader extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const AppSkeletonLoader({
    super.key,
    this.width,
    this.height = 16.0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: borderRadius ?? AppRadius.roundedSm,
        ),
      ),
    );
  }
}

/// Standardized list/table skeleton for pages loading multiple items
class AppListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const AppListSkeleton({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 72.0,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => AppSkeletonLoader(
        height: itemHeight,
        borderRadius: AppRadius.roundedMd,
      ),
    );
  }
}

/// User-friendly, actionable error state for MedSentry EMR.
/// Hides raw SQL/network exceptions from non-technical staff and offers a clear retry action.
class AppErrorState extends StatelessWidget {
  final String title;
  final Object? error;
  final String? friendlyMessage;
  final VoidCallback? onRetry;
  final IconData icon;

  const AppErrorState({
    super.key,
    this.title = 'Unable to load records',
    this.error,
    this.friendlyMessage,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  String _sanitizeErrorMessage(Object? err) {
    if (friendlyMessage != null && friendlyMessage!.isNotEmpty) {
      return friendlyMessage!;
    }
    if (err == null) {
      return 'An unexpected issue occurred while fetching information. Please try again.';
    }

    final raw = err.toString();

    // Sanitize technical Supabase / SQL / Network errors
    if (raw.contains('SocketException') || raw.contains('ClientException') || raw.contains('Failed host lookup')) {
      return 'Network connection is unavailable. Please check your local network or server connection.';
    }
    if (raw.contains('JWT') || raw.contains('auth') || raw.contains('401') || raw.contains('403')) {
      return 'Your clinical session has expired or permissions are restricted. Please sign in again.';
    }
    if (raw.contains('duplicate key') || raw.contains('violates unique constraint')) {
      return 'A record with this information already exists in the system.';
    }
    if (raw.contains('timeout') || raw.contains('TimeoutException')) {
      return 'The health database server took too long to respond. Please retry.';
    }

    // Friendly fallback
    return 'We encountered a problem retrieving this information. Please retry or contact technical support.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final message = _sanitizeErrorMessage(error);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppIconSize.xl,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
