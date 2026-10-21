import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_log.dart';
import '../providers/providers.dart';
import '../widgets/screen_kit.dart';
import '../widgets/loading_state.dart';
import '../widgets/status_badge.dart';
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
    final t = ScreenTokens.of(context);

    List<AuditLog> applyFilters(List<AuditLog> logs) => logs.where((log) {
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

    final allLogs = logsAsync.valueOrNull;
    final shown = allLogs == null ? null : applyFilters(allLogs).length;

    final searchField = SizedBox(
      height: 40,
      child: TextField(
        controller: TextEditingController(text: _searchQuery)
          ..selection = TextSelection.collapsed(offset: _searchQuery.length),
        style: TextStyle(fontSize: 13, color: t.text),
        decoration: InputDecoration(
          hintText: 'Search by user, patient, or description',
          hintStyle: TextStyle(fontSize: 13, color: t.muted),
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: ScreenTokens.radius,
            borderSide: BorderSide(color: t.control),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: ScreenTokens.radius,
            borderSide: BorderSide(color: t.control),
          ),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );

    final actionFilter = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: ScreenTokens.radius,
        border: Border.all(color: t.control),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AuditAction?>(
          // Always bounded (full width on phones, 200px beside the search
          // field), so long action names truncate instead of overflowing.
          isExpanded: true,
          value: _filterAction,
          hint: const Text('All actions', style: TextStyle(fontSize: 13)),
          style: TextStyle(fontFamily: AppType.family, fontSize: 13, color: t.text),
          items: [
            const DropdownMenuItem(value: null, child: Text('All actions', style: TextStyle(fontSize: 13))),
            ...AuditAction.values.map(
              (a) => DropdownMenuItem(value: a, child: Text(_actionLabel(a), style: const TextStyle(fontSize: 13))),
            ),
          ],
          onChanged: (v) => setState(() => _filterAction = v),
        ),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            icon: Icons.history_edu_outlined,
            title: 'Audit Logs',
            subtitle: allLogs == null
                ? 'Sign-ins, record changes and staff actions, newest first.'
                : (shown == allLogs.length
                      ? '${allLogs.length} logged ${allLogs.length == 1 ? 'event' : 'events'}: sign-ins, record changes and staff actions, newest first.'
                      : 'Showing $shown of ${allLogs.length} logged events.'),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    actionFilter,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  SizedBox(width: 200, child: actionFilter),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          logsAsync.when(
            skipLoadingOnReload: true,
            data: (logs) {
              final filtered = applyFilters(logs);

              if (filtered.isEmpty) {
                return EmptyPanel(
                  icon: Icons.history_edu_outlined,
                  message: logs.isEmpty
                      ? 'No activity logged yet'
                      : 'No entries match these filters',
                  detail: logs.isEmpty
                      ? 'Sign-ins, record changes and staff actions are recorded here as they happen.'
                      : 'Clear the search or choose All actions to see every entry.',
                );
              }

              return RowsPanel(
                children: [
                  for (final log in filtered)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Icon(
                        _actionIcon(log.action),
                        size: 18,
                        color: t.muted,
                      ),
                      minLeadingWidth: 20,
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${log.actionDisplay}: ${log.entityType}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: t.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildActionBadge(log.action),
                        ],
                      ),
                      subtitle: Text(
                        '${log.userName ?? log.userId}, ${_formatDateTime(log.timestamp)}'
                        '${log.patientName != null ? '. Patient: ${log.patientName}' : ''}'
                        '${log.description != null ? '\n${log.description}' : ''}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: t.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      isThreeLine: log.description != null,
                    ),
                ],
              );
            },
            loading: () => const LoadingState(),
            error: (error, _) => AppErrorState(
              title: 'Audit logs could not be loaded',
              error: error,
              onRetry: () => ref.invalidate(auditLogsProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBadge(AuditAction action) {
    return switch (action) {
      AuditAction.delete => StatusBadge.critical(text: 'Deleted'),
      AuditAction.update => StatusBadge.pending(text: 'Updated'),
      AuditAction.create => StatusBadge.normal(text: 'Created'),
      AuditAction.login || AuditAction.logout =>
        StatusBadge.info(text: action == AuditAction.login ? 'Login' : 'Logout'),
      AuditAction.sync || AuditAction.backup || AuditAction.restore =>
        StatusBadge.normal(text: action.name.toUpperCase()),
      _ => StatusBadge.neutral(text: action.name.toUpperCase()),
    };
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

  String _formatDateTime(DateTime dt) {
    return formatDateTime12h(dt);
  }
}
