import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_design_tokens.dart';
import '../models/patient.dart';
import '../utils/context_extensions.dart';

class PatientPreviewPanel extends StatelessWidget {
  final Patient patient;
  final VoidCallback? onOpenRecord;

  const PatientPreviewPanel({
    super.key,
    required this.patient,
    this.onOpenRecord,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.sidebarBackground : Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryEmeraldSubtle,
                  child: Text(
                    _initialsFor(patient),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.lightTextPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${patient.id}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (patient.category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmeraldSubtle,
                      borderRadius: AppRadius.roundedPill,
                      border: Border.all(
                        color: AppColors.primaryEmerald.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      patient.category!.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                if (patient.isPwd)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.elevatedSurface
                          : AppColors.lightElevatedSurface,
                      borderRadius: AppRadius.roundedPill,
                      border: Border.all(
                        color: isDark
                            ? AppColors.border
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.accessible,
                          size: 13,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PWD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (patient.is4PsBeneficiary)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.semanticColors.warningBg,
                      borderRadius: AppRadius.roundedPill,
                      border: Border.all(
                        color: context.semanticColors.warning.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    child: Text(
                      '4Ps',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.semanticColors.warning,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _PreviewSection(
              title: 'Demographics',
              rows: [
                _PreviewRow('Age', '${patient.age ?? 'N/A'} years'),
                _PreviewRow('Gender', patient.gender ?? 'N/A'),
                _PreviewRow('Contact', patient.contactNumber ?? 'N/A'),
                _PreviewRow('Barangay', patient.barangay ?? 'Not recorded'),
              ],
            ),
            const SizedBox(height: 14),
            _PreviewSection(
              title: 'Medical',
              rows: [
                _PreviewRow('Blood type', patient.bloodType ?? 'N/A'),
                _PreviewRow('Allergies', patient.allergies ?? 'None recorded'),
                _PreviewRow('PhilHealth', patient.philHealthNumber ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    onOpenRecord ??
                    () => context.push('/patients/${patient.id}'),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open Record'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  foregroundColor: AppColors.textOnEmerald,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.roundedSm,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _initialsFor(Patient patient) {
  if (patient.firstName.isNotEmpty && patient.lastName.isNotEmpty) {
    return '${patient.firstName[0]}${patient.lastName[0]}'.toUpperCase();
  }
  return '?';
}

class _PreviewSection extends StatelessWidget {
  final String title;
  final List<_PreviewRow> rows;

  const _PreviewSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : AppColors.lightCardSurface,
        borderRadius: AppRadius.roundedSm,
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.lightBorder,
          width: AppColors.borderWidth,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      row.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow {
  final String label;
  final String value;

  const _PreviewRow(this.label, this.value);
}
