import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_log.dart';
import '../providers/providers.dart';
import '../widgets/loading_state.dart';
import '../widgets/status_badge.dart';
import '../widgets/layout/responsive_layout.dart';
import '../utils/context_extensions.dart';
import '../utils/date_time_format.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  AuditAction? _filterAction;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsProvider);

    return ResponsiveContentContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.isMobile ? 16 : 24,
              20,
              context.isMobile ? 16 : 24,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audit Logs & Activity Monitoring',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track login history, record changes, staff actions, and suspicious activity.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    final searchField = TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by user, patient, or description...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    );
                    final actionDropdown = DropdownButton<AuditAction?>(
                      value: _filterAction,
                      hint: const Text('All Actions'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Actions'),
                        ),
                        ...AuditAction.values.map(
                          (a) => DropdownMenuItem(
                            value: a,
                            child: Text(_actionLabel(a)),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterAction = v),
                    );

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          searchField,
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: actionDropdown,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 12),
                        actionDropdown,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                final filtered = logs.where((log) {
                  if (_filterAction != null && log.action != _filterAction) {
                    return false;
                  }
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return (log.userName?.toLowerCase().contains(q) ?? false) ||
                      (log.patientName?.toLowerCase().contains(q) ?? false) ||
                      (log.description?.toLowerCase().contains(q) ?? false) ||
                      log.entityType.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No audit log entries found.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    final color = _actionColor(context, log.action);
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
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withValues(alpha: 0.2)),
                          ),
                          child: Icon(
                            _actionIcon(log.action),
                            color: color,
                            size: 18,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${log.actionDisplay} — ${log.entityType}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge.info(text: log.action.name.toUpperCase(), showDot: true),
                          ],
                        ),
                        subtitle: Text(
                          '${log.userName ?? log.userId} • ${_formatDateTime(log.timestamp)}'
                          '${log.patientName != null ? ' • ${log.patientName}' : ''}'
                          '${log.description != null ? '\n${log.description}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        isThreeLine: log.description != null,
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingState(),
              error: (error, _) => AppErrorState(
                title: 'Audit logs could not be loaded',
                error: error,
                onRetry: () => ref.invalidate(auditLogsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _actionLabel(AuditAction action) {
    switch (action) {
      case AuditAction.login:
        return 'Login';
      case AuditAction.logout:
        return 'Logout';
      case AuditAction.create:
        return 'Create';
      case AuditAction.update:
        return 'Update';
      case AuditAction.delete:
        return 'Delete';
      case AuditAction.sync:
        return 'Sync';
      case AuditAction.backup:
        return 'Backup';
      case AuditAction.restore:
        return 'Restore';
      default:
        return action.name;
    }
  }

  IconData _actionIcon(AuditAction action) {
    switch (action) {
      case AuditAction.login:
      case AuditAction.logout:
        return Icons.login;
      case AuditAction.create:
        return Icons.add_circle_outline;
      case AuditAction.update:
        return Icons.edit_outlined;
      case AuditAction.delete:
        return Icons.delete_outline;
      case AuditAction.sync:
        return Icons.cloud_sync_outlined;
      default:
        return Icons.history;
    }
  }

  Color _actionColor(BuildContext context, AuditAction action) {
    final colors = context.semanticColors;
    switch (action) {
      case AuditAction.delete:
        return colors.critical;
      case AuditAction.login:
      case AuditAction.logout:
        return colors.info;
      case AuditAction.sync:
      case AuditAction.backup:
      case AuditAction.create:
        return colors.normal;
      case AuditAction.update:
        return colors.warning;
      default:
        return colors.neutral;
    }
  }

  String _formatDateTime(DateTime dt) {
    return formatDateTime12h(dt);
  }
}
