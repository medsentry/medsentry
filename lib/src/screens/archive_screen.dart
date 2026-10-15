import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../widgets/app_card.dart';
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
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 20, isMobile ? 16 : 24, 0),
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
                    color: AppColors.textSecondary,
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
                  padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 0, isMobile ? 16 : 24, 24),
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.elevatedSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.border,
                            ),
                          ),
                          child: const Icon(Icons.archive_outlined, size: 18, color: AppColors.textSecondary),
                        ),
                        title: Text(patient.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'ID: ${patient.id}'
                          '${patient.archivedAt != null ? ' • Archived ${_formatDate(patient.archivedAt!)}' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      trailing: isMobile
                          ? PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              tooltip: 'Actions',
                              onSelected: (value) async {
                                if (value == 'view') {
                                  context.go('/patients/${patient.id}');
                                } else if (value == 'restore') {
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
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: ListTile(
                                    leading: Icon(Icons.visibility_outlined),
                                    title: Text('View Record'),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'restore',
                                  child: ListTile(
                                    leading: Icon(Icons.unarchive_outlined),
                                    title: Text('Restore Patient'),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
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
