import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_notification.dart';
import '../providers/providers.dart';
import '../widgets/app_card.dart';
import '../widgets/layout/responsive_layout.dart';
import '../utils/context_extensions.dart';
import '../utils/date_time_format.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _isSyncing = false;
  SyncStats? _stats;
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await ref.read(syncServiceProvider).getSyncStats();
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _startSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _lastMessage = null;
    });

    try {
      final result = await ref.read(syncServiceProvider).startSync();
      await _loadStats();
      ref.invalidate(extendedDashboardStatsProvider);

      if (mounted) {
        setState(() {
          _lastMessage = result.message;
        });
        if (result.success) {
          AppNotification.success(
            title: 'Sync Complete',
            message: result.message,
          );
        } else {
          AppNotification.error(title: 'Sync Failed', message: result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastMessage = 'Sync error: $e';
        });
        AppNotification.error(
          title: 'Sync Failed',
          message: 'An unexpected error occurred during sync: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);
    final lastSync = ref.watch(lastSyncTimeProvider);

    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context),
      child: ResponsiveContentContainer(
        maxWidth: 960,
        padding: EdgeInsets.zero,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record Synchronization',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Synchronize updated records between local storage and cloud when internet is available.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatusCard(
                icon: Icons.cloud_outlined,
                title: 'Sync Status',
                value: _statusLabel(syncStatus),
                color: _statusColor(context, syncStatus),
              ),
              _StatusCard(
                icon: Icons.schedule_outlined,
                title: 'Last Sync',
                value: lastSync != null ? _formatDateTime(lastSync) : 'Never',
                color: context.semanticColors.info,
              ),
              if (_stats != null)
                _StatusCard(
                  icon: Icons.pending_actions_outlined,
                  title: 'Pending Records',
                  value: '${_stats!.pendingSync}',
                  color: _stats!.pendingSync > 0
                      ? context.semanticColors.warning
                      : context.semanticColors.normal,
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (_stats != null) ...[
            Text(
              'Local Database',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.people_outlined, color: AppColors.primaryEmerald),
                    title: const Text('Patients'),
                    trailing: Text(
                      '${_stats!.totalPatients}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.folder_outlined, color: AppColors.info),
                    title: const Text('Documents'),
                    trailing: Text(
                      '${_stats!.totalDocuments}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isSyncing ? null : _startSync,
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined),
            label: Text(_isSyncing ? 'Synchronizing...' : 'Sync Now'),
          ),
          if (_lastMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _lastMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  String _statusLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.pending:
        return 'Pending';
      case SyncStatus.error:
        return 'Error';
      case SyncStatus.offline:
        return 'Offline';
    }
  }

  Color _statusColor(BuildContext context, SyncStatus status) {
    final colors = context.semanticColors;
    switch (status) {
      case SyncStatus.synced:
        return colors.normal;
      case SyncStatus.syncing:
        return colors.info;
      case SyncStatus.pending:
        return colors.warning;
      case SyncStatus.error:
        return colors.critical;
      case SyncStatus.offline:
        return colors.neutral;
    }
  }

  String _formatDateTime(DateTime dt) {
    return formatDateTime12h(dt);
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    return SizedBox(
      width: isMobile ? double.infinity : 220,
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
