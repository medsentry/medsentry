import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_design_tokens.dart';
import '../utils/context_extensions.dart';

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
    final isDark = theme.brightness == Brightness.dark;

    final indicator = SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryEmerald),
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
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
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
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
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
    final baseColor = isDark
        ? AppColors.elevatedSurface
        : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? AppColors.border : const Color(0xFFF1F5F9);

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
    if (raw.contains('SocketException') ||
        raw.contains('ClientException') ||
        raw.contains('Failed host lookup')) {
      return 'Network connection is unavailable. Please check your local network or server connection.';
    }
    if (raw.contains('JWT') ||
        raw.contains('auth') ||
        raw.contains('401') ||
        raw.contains('403')) {
      return 'Your clinical session has expired or permissions are restricted. Please sign in again.';
    }
    if (raw.contains('duplicate key') ||
        raw.contains('violates unique constraint')) {
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
    final isDark = theme.brightness == Brightness.dark;
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
                color: context.semanticColors.criticalBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.semanticColors.critical.withValues(
                    alpha: 0.35,
                  ),
                ),
              ),
              child: Icon(
                icon,
                size: AppIconSize.lg,
                color: context.semanticColors.critical,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
