import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/date_time_format.dart';
import '../widgets/screen_kit.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedPatientsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final canDelete = currentUser?.permissions.canDeletePatientRecords ?? false;
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final t = ScreenTokens.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            icon: Icons.inventory_2_outlined,
            title: 'Archive & Recovery',
            subtitle: switch (archivedAsync.valueOrNull?.length) {
              null =>
                'Inactive patient records, kept until restored or deleted.',
              0 => 'No patient records are archived.',
              1 =>
                '1 archived patient record. Restore it to make it active again.',
              final n =>
                '$n archived patient records. Restore one to make it active again.',
            },
          ),
          const SizedBox(height: 16),
          archivedAsync.when(
            skipLoadingOnReload: true,
            data: (patients) {
              if (patients.isEmpty) {
                return const EmptyPanel(
                  icon: Icons.inventory_2_outlined,
                  message: 'No archived patient records',
                  detail:
                      'Patients you archive from the registry appear here until they are restored.',
                );
              }

              return RowsPanel(
                children: [
                  for (final patient in patients)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: t.isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: t.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          patient.fullName.isNotEmpty
                              ? patient.fullName
                                  .trim()
                                  .split(' ')
                                  .map((e) => e.isNotEmpty ? e[0] : '')
                                  .take(2)
                                  .join()
                                  .toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: t.muted,
                          ),
                        ),
                      ),
                      title: Text(
                        patient.fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: t.text,
                        ),
                      ),
                      subtitle: Text(
                        'ID: ${patient.id}'
                        '${patient.archivedAt != null ? ' · Archived ${formatDateTime12h(patient.archivedAt!)}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: t.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
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
                                  await _restorePatient(context, ref, patient);
                                } else if (value == 'delete') {
                                  await _permanentlyDeletePatient(
                                    context,
                                    ref,
                                    patient,
                                  );
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
                                if (canDelete)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.delete_forever_outlined,
                                        color: AppColors.dangerRed,
                                      ),
                                      title: Text(
                                        'Delete Permanently',
                                        style: TextStyle(
                                          color: AppColors.dangerRed,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  ),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      context.go('/patients/${patient.id}'),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('View'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: t.text,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    side: BorderSide(color: t.control),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: () =>
                                      _restorePatient(context, ref, patient),
                                  icon: const Icon(
                                    Icons.unarchive_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Restore'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: t.accent,
                                    foregroundColor: t.onAccent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (canDelete) ...[
                                  const SizedBox(width: 6),
                                  IconButton(
                                    tooltip: 'Delete Permanently',
                                    icon: const Icon(
                                      Icons.delete_forever_outlined,
                                      size: 18,
                                      color: AppColors.dangerRed,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _permanentlyDeletePatient(
                                      context,
                                      ref,
                                      patient,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                ],
              );
            },
            loading: () => const LoadingState(),
            error: (error, _) => AppErrorState(
              title: 'Archived patients could not be loaded',
              error: error,
              onRetry: () => ref.invalidate(archivedPatientsProvider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restorePatient(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final userId = ref.read(currentUserProvider)?.id ?? 'system';
    await ref
        .read(patientRepositoryProvider)
        .restorePatient(patient.id, userId);
    ref.invalidate(archivedPatientsProvider);
    ref.invalidate(patientsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${patient.fullName} restored successfully.')),
      );
    }
  }

  Future<void> _permanentlyDeletePatient(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Permanently Delete Patient Record',
      message:
          'Are you sure you want to permanently delete ${patient.fullName} (${patient.id}) and all associated documents? This action cannot be undone.',
      confirmLabel: 'Delete Forever',
      cancelLabel: 'Cancel',
      isDestructive: true,
      icon: Icons.delete_forever_outlined,
      type: ConfirmDialogType.danger,
    );
    if (confirmed != true) return;
    final userId = ref.read(currentUserProvider)?.id ?? 'system';
    await ref
        .read(patientRepositoryProvider)
        .permanentlyDeletePatient(patient.id, userId);
    ref.invalidate(archivedPatientsProvider);
    ref.invalidate(patientsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${patient.fullName} permanently deleted.')),
      );
    }
  }
}
