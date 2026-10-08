import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';

/// Standardized actionable Empty State for MedSentry EMR.
class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  /// Factory for empty patient records
  factory EmptyState.patients({VoidCallback? onRegister}) {
    return EmptyState(
      icon: Icons.people_outline,
      title: 'No registered patients yet',
      message:
          'Patients registered in this Rural Health Unit will appear here with full clinical history.',
      action: onRegister != null
          ? FilledButton.icon(
              onPressed: onRegister,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Register Patient'),
            )
          : null,
    );
  }

  /// Factory for search with zero matches
  factory EmptyState.search({String? query, VoidCallback? onClear}) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: query != null && query.isNotEmpty
          ? 'No matches for "$query"'
          : 'No records found',
      message:
          'Double check spelling, try another keyword, PhilHealth number, or clear filters.',
      action: onClear != null
          ? OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear Search & Filters'),
            )
          : null,
    );
  }

  /// Factory for empty documents
  factory EmptyState.documents({VoidCallback? onUpload}) {
    return EmptyState(
      icon: Icons.folder_open_outlined,
      title: 'No medical documents on record',
      message:
          'Lab results, diagnostic imaging, and clinical scanned files will be listed here.',
      action: onUpload != null
          ? FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Upload Document'),
            )
          : null,
    );
  }

  /// Factory for empty audit logs
  factory EmptyState.auditLogs() {
    return const EmptyState(
      icon: Icons.history_outlined,
      title: 'No audit events found',
      message:
          'Platform security and operational audit records will appear here.',
    );
  }

  /// Factory for empty RHU facilities
  factory EmptyState.rhus({VoidCallback? onAddFacility}) {
    return EmptyState(
      icon: Icons.domain_outlined,
      title: 'No health facilities registered',
      message:
          'Registered Rural Health Units across the municipality will be organized here.',
      action: onAddFacility != null
          ? FilledButton.icon(
              onPressed: onAddFacility,
              icon: const Icon(Icons.domain_add_outlined, size: 18),
              label: const Text('Register First RHU'),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppIconSize.xl,
                color: colorScheme.primary,
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
                color: colorScheme.onSurface.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
