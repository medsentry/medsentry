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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.68),
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

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: patients.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.archive_outlined),
                      ),
                      title: Text(patient.fullName),
                      subtitle: Text(
                        'ID: ${patient.id}'
                        '${patient.archivedAt != null ? ' • Archived ${_formatDate(patient.archivedAt!)}' : ''}',
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
                                      ScaffoldMessenger.of(context).showSnackBar(
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
                                      ScaffoldMessenger.of(context).showSnackBar(
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
                    );
                  },
                );
              },
              loading: () => const LoadingState(),
              error: (e, _) => Center(child: Text('Error: $e')),
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
