import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_notification.dart';
import '../providers/providers.dart';
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
    setState(() {
      _isSyncing = true;
      _lastMessage = null;
    });

    final result = await ref.read(syncServiceProvider).startSync();
    await _loadStats();
    ref.invalidate(extendedDashboardStatsProvider);

    if (mounted) {
      setState(() {
        _isSyncing = false;
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
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);
    final lastSync = ref.watch(lastSyncTimeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.people_outlined),
                    title: const Text('Patients'),
                    trailing: Text('${_stats!.totalPatients}'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.medical_services_outlined),
                    title: const Text('Consultations'),
                    trailing: Text('${_stats!.totalConsultations}'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Documents'),
                    trailing: Text('${_stats!.totalDocuments}'),
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
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
