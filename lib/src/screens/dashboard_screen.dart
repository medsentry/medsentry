import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/clinic.dart';
import '../models/queue.dart';
import '../models/patient.dart';
import '../models/audit_log.dart';
import '../models/user.dart';
import '../providers/providers.dart';
import '../utils/context_extensions.dart';
import '../utils/date_time_format.dart';
import '../widgets/app_card.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';
import '../widgets/status_badge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser?.isSuperAdmin == true) {
      return _buildSuperAdminDashboard(context, ref, currentUser!);
    }

    final syncStatus = ref.watch(syncStatusProvider);
    final dashboardStats = ref.watch(dashboardStatsProvider);
    final extendedStats = ref.watch(extendedDashboardStatsProvider);
    final queueAsync = ref.watch(queueProvider);
    final reportStats = ref.watch(reportStatsProvider);

    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context),
      child: ResponsiveContentContainer(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHero(context, currentUser?.name ?? 'User'),
            const SizedBox(height: 16),
            _buildQuickActionBar(context, currentUser),
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
        color: colors.info,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Mobile (< 480): 1 col, Tablet (480-1024): 2 cols, Desktop (> 1024): 4 cols
        final int columns = width < 480
            ? 1
            : width <= 1024
                ? 2
                : 4;
        const spacing = 12.0;
        final cardWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: cardWidth,
                  child: _buildStatCard(context, card),
                ),
              )
              .toList(),
        );
      },
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
                    color: colors.normal,
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
                  'Active Users',
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

    // Desktop split layout (> 1024px): Side-by-side 2-column data panels
    if (context.isDesktop && hasPatients && hasActivity) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildRecentPatientsPanel(
              context,
              user,
              stats.recentPatients,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _buildStaffActivityPanel(context, stats.recentActivity),
          ),
        ],
      );
    }

    // Mobile & Tablet: Stacked clean cards
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPatients)
          _buildRecentPatientsPanel(context, user, stats.recentPatients),
        if (hasPatients && hasActivity) const SizedBox(height: 20),
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
    return formatTime12h(dt);
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

  Widget _buildQuickActionBar(BuildContext context, User? user) {
    final canRegister = user?.canRegisterPatients == true;
    final canQueue = user?.canManageQueue == true;
    final canVitals = user?.canRecordVitals == true;
    final canConsult = user?.canConsult == true;
    final canReports = user?.canGenerateReports == true;
    final canDocs = user?.canManageDocuments == true;
    final canStaff = user?.canManageStaffAccounts == true || user?.isSuperAdmin == true;

    final actions = <Widget>[
      if (canRegister)
        _QuickActionButton(
          icon: Icons.person_add_alt_1_outlined,
          label: 'Register Patient',
          onTap: () => context.go('/patients?add=true'),
          isPrimary: true,
        ),
      if (canQueue)
        _QuickActionButton(
          icon: Icons.queue_outlined,
          label: 'Manage Queue',
          onTap: () => context.go('/queue'),
        ),
      if (canVitals && !canQueue)
        _QuickActionButton(
          icon: Icons.monitor_heart_outlined,
          label: 'Record Vitals',
          onTap: () => context.go('/queue'),
        ),
      if (canConsult)
        _QuickActionButton(
          icon: Icons.medical_services_outlined,
          label: 'Consultation Station',
          onTap: () => context.go('/queue'),
        ),
      if (canDocs)
        _QuickActionButton(
          icon: Icons.document_scanner_outlined,
          label: 'Document Hub',
          onTap: () => context.go('/documents'),
        ),
      if (canReports)
        _QuickActionButton(
          icon: Icons.insights_outlined,
          label: 'Reports & Analytics',
          onTap: () => context.go('/reports'),
        ),
      if (canStaff)
        _QuickActionButton(
          icon: Icons.manage_accounts_outlined,
          label: 'Staff Directory',
          onTap: () => context.go('/staff'),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions
            .map((w) => Padding(padding: const EdgeInsets.only(right: 10), child: w))
            .toList(),
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
        title: 'Manage Users',
        description: 'Create user accounts, assign roles, and manage access.',
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
    return _InteractiveStatCard(data: data);
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuperAdminDashboard(
    BuildContext context,
    WidgetRef ref,
    User currentUser,
  ) {
    final clinicsAsync = ref.watch(clinicsProvider);
    final usersAsync = ref.watch(usersProvider);
    final patientsAsync = ref.watch(patientsProvider);
    final auditLogsAsync = ref.watch(auditLogsProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final colors = context.semanticColors;

    final totalClinics = clinicsAsync.value?.length ?? 0;
    final totalUsers = usersAsync.value?.length ?? 0;
    final totalPatients = patientsAsync.value?.length ?? 0;
    final totalLogs = auditLogsAsync.value?.length ?? 0;

    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context),
      child: ResponsiveContentContainer(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSuperAdminHero(context, currentUser.fullName),
            const SizedBox(height: 24),
            Text(
              'Provincial Overview',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final int columns = width < 480
                    ? 1
                    : width <= 1024
                        ? 2
                        : 4;
                const spacing = 12.0;
                final cardWidth = (width - (spacing * (columns - 1))) / columns;

                final cards = [
                  _StatCardData(
                    icon: Icons.domain_outlined,
                    title: 'Rural Health Units',
                    value: clinicsAsync.isLoading
                        ? '...'
                        : totalClinics.toString(),
                    subtitle: 'Active healthcare facilities',
                    color: colors.info,
                    onTap: () => context.go('/rhus'),
                  ),
                  _StatCardData(
                    icon: Icons.badge_outlined,
                    title: 'Platform Users',
                    value: usersAsync.isLoading ? '...' : totalUsers.toString(),
                    subtitle: 'RHU admins & health staff',
                    color: colors.normal,
                    onTap: () => context.go('/staff'),
                  ),
                  _StatCardData(
                    icon: Icons.people_outline,
                    title: 'Total Patients',
                    value: patientsAsync.isLoading
                        ? '...'
                        : totalPatients.toString(),
                    subtitle: 'Registered across province',
                    color: colors.neutral,
                    onTap: () => context.go('/reports'),
                  ),
                  _StatCardData(
                    icon: Icons.shield_outlined,
                    title: 'Audit Logs',
                    value: auditLogsAsync.isLoading
                        ? '...'
                        : totalLogs.toString(),
                    subtitle: 'Recorded security & audit events',
                    color: colors.warning,
                    onTap: () => context.go('/audit-logs'),
                  ),
                ];

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: cards
                      .map(
                        (card) => SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(context, card),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildAlertCard(
              context,
              icon: Icons.verified_user_outlined,
              title: 'Platform System Status: Operational',
              description: syncStatus == SyncStatus.synced
                  ? 'All RHU municipal databases are synchronized and encrypted with cloud backup.'
                  : 'Synchronization process active. Cloud sync is maintaining data consistency.',
              color: syncStatus == SyncStatus.synced
                  ? colors.normal
                  : colors.warning,
            ),
            const SizedBox(height: 24),
            Text(
              'System Management Workflows',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Platform configuration, municipality onboarding, and provincial oversight.',
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

                final actions = [
                  _WorkflowAction(
                    icon: Icons.domain_add_outlined,
                    title: 'Manage Rural Health Units',
                    description:
                        'Create new RHU facilities, configure clinic codes, addresses, and scopes.',
                    color: colors.info,
                    onTap: () => context.go('/rhus'),
                  ),
                  _WorkflowAction(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Manage RHU Administrators',
                    description:
                        'Provision municipal admin credentials and oversee staff assignments.',
                    color: colors.normal,
                    onTap: () => context.go('/staff'),
                  ),
                  _WorkflowAction(
                    icon: Icons.query_stats_outlined,
                    title: 'Provincial Health Reports',
                    description:
                        'Aggregate FHSIS summaries, morbidity data, and cross-facility analytics.',
                    color: colors.neutral,
                    onTap: () => context.go('/reports'),
                  ),
                  _WorkflowAction(
                    icon: Icons.history_edu_outlined,
                    title: 'Global Security & Audit Trail',
                    description:
                        'Audit access patterns, failed logins, credential changes, and system events.',
                    color: colors.warning,
                    onTap: () => context.go('/audit-logs'),
                  ),
                ];

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
            const SizedBox(height: 24),
            // Desktop (> 1024px): Side-by-side data panels
            if (context.isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: clinicsAsync.when(
                      data: (clinics) =>
                          _buildSuperAdminClinicsPanel(context, clinics),
                      loading: () => const AppSkeletonLoader(height: 140),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: auditLogsAsync.when(
                      data: (logs) =>
                          _buildSuperAdminAuditPanel(context, logs),
                      loading: () => const AppSkeletonLoader(height: 140),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              )
            else ...[
              clinicsAsync.when(
                data: (clinics) =>
                    _buildSuperAdminClinicsPanel(context, clinics),
                loading: () => const AppSkeletonLoader(height: 140),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              auditLogsAsync.when(
                data: (logs) =>
                    _buildSuperAdminAuditPanel(context, logs),
                loading: () => const AppSkeletonLoader(height: 140),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuperAdminHero(BuildContext context, String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.roundedLg,
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: AppRadius.roundedMd,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Welcome back, $name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: AppRadius.roundedPill,
                      ),
                      child: const Text(
                        'SUPER ADMIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Provincial Health Command Center • MedSentry Platform Oversight',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperAdminClinicsPanel(
    BuildContext context,
    List<Clinic> clinics,
  ) {
    return AppCard(
      titleText: 'Rural Health Units (${clinics.length})',
      subtitle: 'Registered municipality healthcare facilities in province',
      headerAction: TextButton.icon(
        onPressed: () => context.go('/rhus'),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('Manage RHUs'),
      ),
      child: clinics.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No Rural Health Units registered yet.'),
              ),
            )
          : Column(
              children: clinics.take(5).map((clinic) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.local_hospital_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          clinic.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge.active(text: clinic.code),
                    ],
                  ),
                  subtitle: Text(
                    clinic.address?.isNotEmpty == true
                        ? clinic.address!
                        : (clinic.contactNumber ?? 'No contact info'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => context.go('/rhus'),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildSuperAdminAuditPanel(
    BuildContext context,
    List<AuditLog> activity,
  ) {
    return AppCard(
      titleText: 'Global Audit Trail',
      subtitle: 'Recent platform-wide transactions and security logs',
      headerAction: TextButton.icon(
        onPressed: () => context.go('/audit-logs'),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('View All Logs'),
      ),
      child: activity.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No audit logs recorded yet.')),
            )
          : Column(
              children: activity.take(5).map((log) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    Icons.history,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${log.actionDisplay} — ${log.entityType}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      StatusBadge.info(text: log.action.name.toUpperCase()),
                    ],
                  ),
                  subtitle: Text(
                    '${log.userName ?? log.userId} • ${_formatTime(log.timestamp)}',
                  ),
                );
              }).toList(),
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

class _InteractiveStatCard extends StatefulWidget {
  final _StatCardData data;

  const _InteractiveStatCard({required this.data});

  @override
  State<_InteractiveStatCard> createState() => _InteractiveStatCardState();
}

class _InteractiveStatCardState extends State<_InteractiveStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isClickable = data.onTap != null;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isHovered && isClickable
              ? data.color.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: _isHovered && isClickable ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _isHovered && isClickable
                ? data.color.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: _isHovered && isClickable ? 14 : 8,
            offset: Offset(0, _isHovered && isClickable ? 6 : 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          mouseCursor: isClickable
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onHover: (hovering) {
            if (isClickable && mounted) {
              setState(() => _isHovered = hovering);
            }
          },
          onTap: data.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: data.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(data.icon, color: data.color, size: 24),
                      ),
                      if (isClickable)
                        Tooltip(
                          message: 'View ${data.title}',
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _isHovered
                                  ? data.color.withValues(alpha: 0.15)
                                  : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: _isHovered
                                  ? data.color
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    data.value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: data.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  if (data.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      data.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

