import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/patient.dart';
import '../providers/theme_provider.dart';

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
    final categoryColor = _patientCategoryColor(patient.category);

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: categoryColor,
                  child: Text(
                    _initialsFor(patient),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'ID: ${patient.id}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (patient.category != null)
                  Chip(
                    label: Text(patient.category!.displayName),
                    backgroundColor: categoryColor.withValues(alpha: 0.12),
                  ),
                if (patient.isPwd)
                  const Chip(
                    label: Text('PWD'),
                    avatar: Icon(Icons.accessible, size: 16),
                  ),
                if (patient.is4PsBeneficiary) const Chip(label: Text('4Ps')),
              ],
            ),
            const SizedBox(height: 20),
            _PreviewSection(
              title: 'Demographics',
              rows: [
                _PreviewRow('Age', '${patient.age ?? 'N/A'} years'),
                _PreviewRow('Gender', patient.gender ?? 'N/A'),
                _PreviewRow('Contact', patient.contactNumber ?? 'N/A'),
                _PreviewRow('Barangay', patient.barangay ?? 'Not recorded'),
              ],
            ),
            const SizedBox(height: 16),
            _PreviewSection(
              title: 'Medical',
              rows: [
                _PreviewRow('Blood type', patient.bloodType ?? 'N/A'),
                _PreviewRow('Allergies', patient.allergies ?? 'None recorded'),
                _PreviewRow('PhilHealth', patient.philHealthNumber ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    onOpenRecord ??
                    () => context.push('/patients/${patient.id}'),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Record'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _patientCategoryColor(PatientCategory? category) {
    if (category == null) return MedSentryColors.green700;
    switch (category) {
      case PatientCategory.infant:
      case PatientCategory.toddler:
      case PatientCategory.preschool:
      case PatientCategory.pediatric:
        return MedSentryColors.green500;
      case PatientCategory.senior:
      case PatientCategory.seniorCitizen:
        return MedSentryColors.green800;
      case PatientCategory.pregnant:
        return MedSentryColors.emerald600;
      default:
        return MedSentryColors.green700;
    }
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
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.35 : 0.65,
          ),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      row.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
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
