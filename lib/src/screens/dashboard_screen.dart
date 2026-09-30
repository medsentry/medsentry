import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/queue.dart';
import '../models/patient.dart';
import '../models/audit_log.dart';
import '../models/user.dart';
import '../providers/providers.dart';
import '../utils/context_extensions.dart';
import '../widgets/loading_state.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final dashboardStats = ref.watch(dashboardStatsProvider);
    final extendedStats = ref.watch(extendedDashboardStatsProvider);
    final queueAsync = ref.watch(queueProvider);
    final reportStats = ref.watch(reportStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHero(context, currentUser?.name ?? 'User'),
          const SizedBox(height: 20),
          Text(
            'Today\'s Overview',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          dashboardStats.when(
            skipLoadingOnReload: true,
            data: (stats) => _buildKpiRow(context, stats, currentUser),
            loading: () => const LoadingState(),
            error: (error, _) => Text('Error loading stats: $error'),
          ),
          if (currentUser?.canGenerateReports == true) ...[
            const SizedBox(height: 20),
            reportStats.when(
              skipLoadingOnReload: true,
              data: (stats) => _buildAnalyticsPreview(context, stats),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
          if (currentUser?.canViewQueue == true) ...[
            const SizedBox(height: 20),
            _buildLiveQueueStrip(context, queueAsync, currentUser),
          ],
          const SizedBox(height: 24),
          _buildWorkflowSection(context, currentUser),
          const SizedBox(height: 24),
          _buildAlertsColumn(
            context,
            dashboardStats,
            syncStatus,
            extendedStats,
            currentUser,
          ),
          const SizedBox(height: 24),
          extendedStats.when(
            data: (stats) => _buildBottomPanels(context, currentUser, stats),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow(BuildContext context, DashboardStats stats, User? user) {
    final colors = context.semanticColors;

    final cards = [
      _StatCardData(
        icon: Icons.people_alt_outlined,
        title: 'Total Patients',
        value: stats.totalPatients.toString(),
        subtitle: stats.newPatientsToday > 0
            ? '+${stats.newPatientsToday} registered today'
            : 'Registered in clinic',
        color: colors.info, // Changed to Info (Blue) as it's general info
        onTap: user?.canAccessPatientRecords == true
            ? () => context.go('/patients')
            : null,
      ),
      _StatCardData(
        icon: Icons.queue_outlined,
        title: 'In Queue',
        value: stats.activeQueueCount.toString(),
        subtitle: stats.longWaitCount > 0
            ? '${stats.longWaitCount} waiting over 1 hour'
            : 'Active right now',
        color: stats.longWaitCount > 0 ? colors.warning : colors.normal,
        onTap: user?.canViewQueue == true ? () => context.go('/queue') : null,
      ),
      _StatCardData(
        icon: Icons.medical_services_outlined,
        title: 'Consultations Today',
        value: stats.consultationsToday.toString(),
        subtitle: 'Completed and in progress',
        color: colors.normal,
        onTap: user?.canConsult == true
            ? () => context.go('/queue')
            : user?.canGenerateReports == true
            ? () => context.go('/reports')
            : null,
      ),
      _StatCardData(
        icon: Icons.folder_outlined,
        title: 'Documents Today',
        value: stats.documentsToday.toString(),
        subtitle: 'Uploaded or scanned today',
        color: colors.neutral,
        onTap: user?.canManageDocuments == true
            ? () => context.go('/documents')
            : null,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map(
            (card) =>
                SizedBox(width: 260, child: _buildStatCard(context, card)),
          )
          .toList(),
    );
  }

  Widget _buildLiveQueueStrip(
    BuildContext context,
    AsyncValue<List<QueueItem>> queueAsync,
    User? user,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Live Queue',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: () => context.go('/queue'),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open Queue'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        queueAsync.when(
          data: (items) {
            final active =
                items
                    .where(
                      (item) =>
                          item.status == QueueStatus.waiting ||
                          item.status == QueueStatus.inProgress,
                    )
                    .toList()
                  ..sort(
                    (a, b) => b.priority.index.compareTo(a.priority.index),
                  );

            if (active.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: context.semanticColors.normal,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'No patients waiting — queue is clear.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }

            return SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: active.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = active[index];
                  return _QueueStripCard(
                    item: item,
                    onTap: user?.canViewQueue == true
                        ? () => context.go('/queue')
                        : null,
                  );
                },
              ),
            );
          },
          loading: () => const SizedBox(height: 96, child: LoadingState()),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildAlertsColumn(
    BuildContext context,
    AsyncValue<DashboardStats> dashboardStats,
    SyncStatus syncStatus,
    AsyncValue<ExtendedDashboardStats> extendedStats,
    User? user,
  ) {
    final isAdmin = user?.canManageSystemData == true;
    final colors = context.semanticColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Operational Alerts',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        dashboardStats.when(
          data: (stats) {
            if (stats.longWaitCount > 0) {
              return Column(
                children: [
                  _buildAlertCard(
                    context,
                    icon: Icons.warning_amber_rounded,
                    title:
                        '${stats.longWaitCount} patient${stats.longWaitCount == 1 ? '' : 's'} waiting > 1 hour',
                    description:
                        'Consider reassigning staff to triage station.',
                    color: colors.critical,
                  ),
                  const SizedBox(height: 10),
                ],
              );
            }
            return const SizedBox.shrink();
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        _buildAlertCard(
          context,
          icon: Icons.cloud_sync_outlined,
          title: syncStatus == SyncStatus.synced
              ? 'All data synced'
              : 'Pending offline changes',
          description: syncStatus == SyncStatus.synced
              ? 'Your data is up to date and secure.'
              : 'Data will sync automatically once connection stabilizes.',
          color: syncStatus == SyncStatus.synced
              ? colors.normal
              : colors.warning,
        ),
        if (isAdmin)
          extendedStats.when(
            data: (stats) {
              if (stats.unreadNotifications <= 0) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  const SizedBox(height: 10),
                  _buildAlertCard(
                    context,
                    icon: Icons.notifications_active_outlined,
                    title:
                        '${stats.unreadNotifications} unread notification${stats.unreadNotifications == 1 ? '' : 's'}',
                    description:
                        'Review alerts for sync failures, security events, and pending tasks.',
                    color: MedSentryColors.green700,
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        if (isAdmin) ...[
          const SizedBox(height: 20),
          Text(
            'Admin Metrics',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          extendedStats.when(
            data: (stats) => Column(
              children: [
                _buildCompactMetric(
                  context,
                  'Active Staff',
                  stats.activeStaffCount.toString(),
                  Icons.groups_outlined,
                  () => context.go('/staff'),
                ),
                _buildCompactMetric(
                  context,
                  'Pending Docs',
                  stats.pendingDocuments.toString(),
                  Icons.pending_actions_outlined,
                  () => context.go('/documents'),
                ),
                _buildCompactMetric(
                  context,
                  'Archived',
                  stats.archivedPatientCount.toString(),
                  Icons.archive_outlined,
                  () => context.go('/archive'),
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactMetric(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildBottomPanels(
    BuildContext context,
    User? user,
    ExtendedDashboardStats stats,
  ) {
    final isAdmin = user?.canManageSystemData == true;
    final hasPatients = stats.recentPatients.isNotEmpty;
    final hasActivity = isAdmin && stats.recentActivity.isNotEmpty;

    if (!hasPatients && !hasActivity) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPatients)
          _buildRecentPatientsPanel(context, user, stats.recentPatients),
        if (hasPatients && hasActivity) const SizedBox(height: 24),
        if (hasActivity)
          _buildStaffActivityPanel(context, stats.recentActivity),
      ],
    );
  }

  Widget _buildRecentPatientsPanel(
    BuildContext context,
    User? user,
    List<Patient> patients,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Patient Records',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: patients.map((patient) {
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(patient.fullName),
                subtitle: Text('ID: ${patient.id}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: user?.canAccessPatientRecords == true
                    ? () => context.go('/patients/${patient.id}')
                    : null,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffActivityPanel(
    BuildContext context,
    List<AuditLog> activity,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Staff Activity',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () => context.go('/audit-logs'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: activity.take(5).map((log) {
              return ListTile(
                dense: true,
                leading: Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                title: Text('${log.actionDisplay} — ${log.entityType}'),
                subtitle: Text(
                  '${log.userName ?? log.userId} • ${_formatTime(log.timestamp)}',
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildWelcomeHero(BuildContext context, String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.waving_hand_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'RHU Clinical Command Center • MedSentry',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowSection(BuildContext context, User? user) {
    final title = user?.canManageSystemData == true
        ? 'Admin Flow'
        : 'Staff Flow';
    final subtitle = user?.canManageSystemData == true
        ? 'Oversight, reporting, compliance, audit, and system control.'
        : 'Patient registration, triage, queue work, consultation support, and documents.';
    final actions = user?.canManageSystemData == true
        ? _adminWorkflowActions(context)
        : _staffWorkflowActions(context, user);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 680 ? 2 : 1;
            final width =
                (constraints.maxWidth - (12 * (columns - 1))) / columns;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: actions
                  .map(
                    (action) => SizedBox(
                      width: width,
                      child: _buildWorkflowCard(context, action),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  List<_WorkflowAction> _adminWorkflowActions(BuildContext context) {
    final colors = context.semanticColors;
    return [
      _WorkflowAction(
        icon: Icons.monitor_heart_outlined,
        title: 'Monitor Clinic Activity',
        description:
            'Track total patients, active queue, consultations, and long-wait alerts.',
        color: colors.info,
        onTap: () => context.go('/patients'),
      ),
      _WorkflowAction(
        icon: Icons.assessment_outlined,
        title: 'Review Reports',
        description:
            'Open FHSIS / DOH reports, demographic summaries, and exports.',
        color: colors.normal,
        onTap: () => context.go('/reports'),
      ),
      _WorkflowAction(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Manage Staff',
        description: 'Create staff accounts, assign roles, and manage access.',
        color: colors.neutral,
        onTap: () => context.go('/staff'),
      ),
      _WorkflowAction(
        icon: Icons.history_outlined,
        title: 'Review Audit Trail',
        description:
            'Inspect login history, record changes, and staff activity.',
        color: colors.neutral,
        onTap: () => context.go('/audit-logs'),
      ),
    ];
  }

  List<_WorkflowAction> _staffWorkflowActions(
    BuildContext context,
    User? user,
  ) {
    final colors = context.semanticColors;
    return [
      _WorkflowAction(
        icon: Icons.person_search_outlined,
        title: 'Register or Search Patient',
        description:
            'Find an existing record or create a new patient registration.',
        color: colors.info,
        onTap: user?.canAccessPatientRecords == true
            ? () => context.go('/patients')
            : null,
      ),
      _WorkflowAction(
        icon: Icons.vaccines_outlined,
        title: 'Intake and Triage',
        description:
            'Capture vitals, pain scale, red flags, and calculated priority.',
        color: colors.warning,
        onTap: user?.canRecordVitals == true
            ? () => context.go('/queue')
            : null,
      ),
      _WorkflowAction(
        icon: Icons.queue_outlined,
        title: 'Manage Waiting Patients',
        description:
            'Monitor queue status, update stations, and prioritize urgent cases.',
        color: colors.critical,
        onTap: user?.canManageQueue == true ? () => context.go('/queue') : null,
      ),
      _WorkflowAction(
        icon: Icons.folder_outlined,
        title: 'Document Management',
        description:
            'Upload results, prescriptions, X-rays, certificates, and scanned files.',
        color: colors.normal,
        onTap: user?.canManageDocuments == true
            ? () => context.go('/documents')
            : null,
      ),
    ];
  }

  Widget _buildWorkflowCard(BuildContext context, _WorkflowAction action) {
    final enabled = action.onTap != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: enabled ? 0.12 : 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  action.icon,
                  color: enabled
                      ? action.color
                      : Theme.of(context).disabledColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: enabled ? null : Theme.of(context).disabledColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.35,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsPreview(BuildContext context, ReportStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '30-Day Analytics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/reports'),
                  icon: const Icon(Icons.insights_outlined, size: 18),
                  label: const Text('Open Reports'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _AnalyticsChip(
                  label: 'Consultations',
                  value: stats.totalConsultations.toString(),
                  delta: stats.consultationsDelta,
                ),
                _AnalyticsChip(
                  label: 'New patients',
                  value: stats.newPatients.toString(),
                  delta: stats.newPatientsDelta,
                ),
                _AnalyticsChip(
                  label: 'Avg wait',
                  value: stats.avgWaitMinutes > 0
                      ? '${stats.avgWaitMinutes}m'
                      : 'N/A',
                  delta: stats.avgWaitDelta,
                ),
                if (stats.peakConsultationLabel != null)
                  _AnalyticsChip(
                    label: 'Peak day',
                    value: stats.peakConsultationLabel!,
                    delta: null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, _StatCardData data) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(data.icon, color: data.color, size: 32),
              const SizedBox(height: 12),
              Text(
                data.value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: data.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              if (data.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  data.subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueStripCard extends StatelessWidget {
  final QueueItem item;
  final VoidCallback? onTap;

  const _QueueStripCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final statusColor = switch (item.status) {
      QueueStatus.waiting => colors.warning,
      QueueStatus.inProgress => colors.normal,
      _ => colors.neutral,
    };

    return SizedBox(
      width: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.patientName ?? 'Patient',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.purpose ?? item.complaint ?? 'General visit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  item.status.name.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCardData {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _StatCardData({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    required this.color,
    this.onTap,
  });
}

class _AnalyticsChip extends StatelessWidget {
  final String label;
  final String value;
  final MetricDelta? delta;

  const _AnalyticsChip({required this.label, required this.value, this.delta});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (delta != null)
          Text(
            delta!.formatted,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: delta!.isPositive
                  ? context.semanticColors.normal
                  : context.semanticColors.critical,
            ),
          ),
      ],
    );
  }
}

class _WorkflowAction {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback? onTap;

  const _WorkflowAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });
}
