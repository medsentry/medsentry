import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedPatientsProvider);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ResponsiveContentContainer(
      maxWidth: 1100,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Archive & Recovery Management',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage inactive patient records. Restore archived records when needed.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: archivedAsync.when(
              data: (patients) {
                if (patients.isEmpty) {
                  return const Center(
                    child: Text('No archived patient records.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(Icons.archive_outlined, size: 18),
                        ),
                        title: Text(patient.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'ID: ${patient.id}'
                          '${patient.archivedAt != null ? ' • Archived ${_formatDate(patient.archivedAt!)}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      trailing: isMobile
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      context.go('/patients/${patient.id}'),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                  tooltip: 'View',
                                ),
                                IconButton(
                                  onPressed: () async {
                                    await ref
                                        .read(databaseProvider)
                                        .restoreArchivedPatient(patient.id);
                                    ref.invalidate(archivedPatientsProvider);
                                    ref.invalidate(patientsProvider);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${patient.fullName} restored successfully.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.unarchive_outlined,
                                    size: 20,
                                  ),
                                  tooltip: 'Restore',
                                ),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  onPressed: () =>
                                      context.go('/patients/${patient.id}'),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('View'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonalIcon(
                                  onPressed: () async {
                                    await ref
                                        .read(databaseProvider)
                                        .restoreArchivedPatient(patient.id);
                                    ref.invalidate(archivedPatientsProvider);
                                    ref.invalidate(patientsProvider);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${patient.fullName} restored successfully.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.unarchive_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Restore'),
                                ),
                              ],
                            ),
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingState(),
              error: (error, _) => AppErrorState(
                title: 'Archived patients could not be loaded',
                error: error,
                onRetry: () => ref.invalidate(archivedPatientsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
