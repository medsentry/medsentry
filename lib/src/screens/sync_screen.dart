import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_log.dart';
import '../services/app_notification.dart';
import '../providers/providers.dart';
import '../widgets/screen_kit.dart';
import '../widgets/layout/responsive_layout.dart';
import '../utils/date_time_format.dart';
import '../utils/rate_limiter.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _isSyncing = false;
  String? _lastMessage;

  Future<void> _startSync() async {
    if (_isSyncing || ref.read(syncStatusProvider) == SyncStatus.syncing) {
      return;
    }
    final currentUser = ref.read(currentUserProvider);
    final syncKey = currentUser?.id ?? 'sync_user';
    if (!manualSyncRateLimiter.canAttempt(syncKey)) {
      final wait = manualSyncRateLimiter.remainingCooldown(syncKey);
      AppNotification.warning(
        title: 'Sync Throttled',
        message:
            'Please wait ${wait.inSeconds} seconds before requesting another manual sync.',
      );
      return;
    }
    manualSyncRateLimiter.recordAttempt(syncKey);

    setState(() {
      _isSyncing = true;
      _lastMessage = null;
    });

    try {
      final result = await ref.read(syncServiceProvider).startSync();
      final currentUser = ref.read(currentUserProvider);
      await ref
          .read(auditServiceProvider)
          .log(
            userId: currentUser?.id ?? 'system',
            clinicId: currentUser?.clinicId,
            action: AuditAction.sync,
            entityType: 'sync',
            description: 'Manual record synchronization: ${result.message}',
          );
      ref.invalidate(syncStatsProvider);
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
    final stats = ref.watch(syncStatsProvider).valueOrNull;
    final isSyncing = _isSyncing || syncStatus == SyncStatus.syncing;
    final t = ScreenTokens.of(context);

    final pending = stats?.pendingSync;

    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context),
      child: ResponsiveContentContainer(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              icon: Icons.cloud_sync_outlined,
              title: 'Record Synchronization',
              subtitle: pending == null
                  ? 'Local records are sent to the cloud when the internet is available.'
                  : pending == 0
                  ? 'Every local record is in the cloud.'
                  : '$pending local ${pending == 1 ? 'record is' : 'records are'} waiting to be sent to the cloud.',
              actions: [
                FilledButton.icon(
                  style: t.filledButton,
                  onPressed: isSyncing ? null : _startSync,
                  icon: isSyncing
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.onAccent,
                          ),
                        )
                      : const Icon(Icons.cloud_sync_outlined, size: 16),
                  label: Text(isSyncing ? 'Synchronizing...' : 'Sync now'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MetricStrip(
              metrics: [
                Metric(
                  label: 'Sync status',
                  value: _statusLabel(syncStatus),
                  note: _statusNote(syncStatus),
                  noteIsAlert: syncStatus == SyncStatus.error,
                ),
                Metric(
                  label: 'Last sync',
                  value: lastSync != null ? _formatDateTime(lastSync) : 'Never',
                  note: lastSync != null
                      ? 'Last successful upload'
                      : 'No upload yet',
                ),
                Metric(
                  label: 'Pending records',
                  value: pending?.toString() ?? '-',
                  note: pending == null
                      ? 'Counting local changes'
                      : pending == 0
                      ? 'Nothing waiting'
                      : 'Created or changed since the last sync',
                ),
              ],
            ),
            if (_lastMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _lastMessage!,
                style: TextStyle(fontSize: 13, color: t.muted),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              decoration: t.panel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Text(
                      'Local database',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                  ),
                  Divider(height: 1, color: t.border),
                  _countRow(
                    t,
                    Icons.people_outlined,
                    'Patients',
                    stats?.totalPatients,
                  ),
                  Divider(height: 1, indent: 16, color: t.border),
                  _countRow(
                    t,
                    Icons.folder_outlined,
                    'Documents',
                    stats?.totalDocuments,
                  ),
                  Divider(height: 1, indent: 16, color: t.border),
                  _countRow(
                    t,
                    Icons.verified_outlined,
                    'Issued certificates',
                    stats?.totalCertificates,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countRow(ScreenTokens t, IconData icon, String label, int? count) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 18, color: t.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, color: t.text)),
            ),
            Text(
              count?.toString() ?? '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: count == null ? t.muted : t.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
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

  String _statusNote(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return 'Cloud copy is up to date';
      case SyncStatus.syncing:
        return 'Uploading changes now';
      case SyncStatus.pending:
        return 'Changes waiting to upload';
      case SyncStatus.error:
        return 'Last sync failed. Try again.';
      case SyncStatus.offline:
        return 'No internet connection';
    }
  }

  String _formatDateTime(DateTime dt) {
    return formatDateTime12h(dt);
  }
}
