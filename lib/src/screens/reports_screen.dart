import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/generated_report.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/app_notification.dart';
import '../services/report_pdf_service.dart';
import '../services/report_service.dart';
import '../widgets/app_card.dart';
import '../widgets/loading_state.dart';
import '../widgets/report_export_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../utils/context_extensions.dart';
import '../utils/date_time_format.dart';
import '../utils/report_date_filter.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late ReportFilters _draftFilters;
  String _activeTab = 'reports'; // 'reports', 'visits', or 'logs'
  String _reportSearchQuery = '';
  String _reportTypeFilter = 'all';
  String _reportSortOrder = 'newest';
  String _auditSearchQuery = '';
  String _auditActionFilter = 'all';
  bool _isExportingConsultations = false;
  late final TextEditingController _reportSearchController;
  late final TextEditingController _auditSearchController;

  @override
  void initState() {
    super.initState();
    _draftFilters = ref.read(reportFiltersProvider);
    _reportSearchController = TextEditingController();
    _auditSearchController = TextEditingController();
  }

  @override
  void dispose() {
    _reportSearchController.dispose();
    _auditSearchController.dispose();
    super.dispose();
  }

  List<double> _valuesFromTrends(List<ReportTrend> trends) {
    return trends.map((t) => t.count.toDouble()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ref.watch(reportFiltersProvider);
    final reportStatsAsync = ref.watch(reportStatsProvider);
    final generatedReportsAsync = ref.watch(generatedReportsProvider);
    final consultationEntriesAsync = _activeTab == 'visits'
        ? ref.watch(consultationReportEntriesProvider)
        : const AsyncValue<List<ConsultationReportEntry>>.loading();

    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context),
      child: ResponsiveContentContainer(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports & Analytics',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Patient and document statistics for the selected period.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),

            _buildRangeSelector(context),
            const SizedBox(height: 12),

            reportStatsAsync.when(
              skipLoadingOnReload: true,
              data: (stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (stats.newPatients == 0 &&
                      stats.documentsInRange == 0) ...[
                    _buildNoReportData(context),
                    const SizedBox(height: 12),
                  ],
                  _buildKpiGrid(context, stats),
                  const SizedBox(height: 16),
                  _buildAnalyticsCharts(context, stats),
                  const SizedBox(height: 16),
                  _buildDemographicsSection(context, stats),
                ],
              ),
              loading: () => const LoadingState(),
              error: (error, stack) => _buildReportError(
                context,
                onRetry: () => ref.invalidate(reportStatsProvider),
              ),
            ),
            const SizedBox(height: 20),

            _buildSection(context, 'Patient Reports', [
              _buildReportCard(
                context,
                'Patient Statistics',
                'Patient demographics and visit statistics',
                Icons.people_outline,
                context.semanticColors.normal,
                () => _showDateRangeDialog(context, 'Patient Statistics'),
              ),
            ]),
            const SizedBox(height: 24),
            _buildTabSelector(context),
            const SizedBox(height: 16),
            if (_activeTab == 'reports')
              _buildGeneratedReportsSection(context, generatedReportsAsync)
            else if (_activeTab == 'visits')
              _buildConsultationReport(
                context,
                consultationEntriesAsync,
                filters,
              )
            else
              _buildHistoricalAuditLogsSection(context),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

  Widget _buildRangeSelector(BuildContext context) {
    final canApply =
        !_draftFilters.endDate.isBefore(_draftFilters.startDate) &&
        !_draftFilters.endDate.isAfter(DateTime.now());

    return SizedBox(
      width: double.infinity,
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isVeryNarrow = width < 420;
            final isNarrow = width < 600;
            final dropdownWidth = isVeryNarrow
                ? width
                : isNarrow
                    ? (width - 12) / 2
                    : 180.0;
            final groupingWidth = isVeryNarrow
                ? width
                : isNarrow
                    ? (width - 12) / 2
                    : 150.0;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: dropdownWidth,
                  child: DropdownButtonFormField<ReportDatePreset>(
                    initialValue: _draftFilters.preset,
                    decoration: const InputDecoration(
                      labelText: 'Date Range',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ReportDatePreset.values
                        .map(
                          (preset) => DropdownMenuItem(
                            value: preset,
                            child: Text(preset.label),
                          ),
                        )
                        .toList(),
                    onChanged: (preset) {
                      if (preset == null) return;
                      setState(() {
                        _draftFilters = ReportFilters.forPreset(
                          preset,
                          grouping: _draftFilters.grouping,
                        );
                      });
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickReportStartDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('From ${_formatDate(_draftFilters.startDate)}'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickReportEndDate,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text('To ${_formatDate(_draftFilters.endDate)}'),
                ),
                SizedBox(
                  width: groupingWidth,
                  child: DropdownButtonFormField<ReportGrouping>(
                    initialValue: _draftFilters.grouping,
                    decoration: const InputDecoration(
                      labelText: 'Group By',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ReportGrouping.values
                        .map(
                          (grouping) => DropdownMenuItem(
                            value: grouping,
                            child: Text(grouping.label),
                          ),
                        )
                        .toList(),
                    onChanged: (grouping) {
                      if (grouping != null) {
                        setState(() {
                          _draftFilters = _draftFilters.copyWith(
                            grouping: grouping,
                          );
                        });
                      }
                    },
                  ),
                ),
                FilledButton.icon(
                  onPressed: canApply ? _applyReportFilters : null,
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('Apply Filters'),
                ),
                TextButton.icon(
                  onPressed: _resetReportFilters,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickReportStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _draftFilters.startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _draftFilters = _draftFilters.copyWith(
        preset: ReportDatePreset.custom,
        startDate: selected,
        endDate: _draftFilters.endDate.isBefore(selected)
            ? selected
            : _draftFilters.endDate,
      );
    });
  }

  Future<void> _pickReportEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _draftFilters.endDate.isBefore(_draftFilters.startDate)
          ? _draftFilters.startDate
          : _draftFilters.endDate,
      firstDate: _draftFilters.startDate,
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _draftFilters = _draftFilters.copyWith(
        preset: ReportDatePreset.custom,
        endDate: selected,
      );
    });
  }

  void _applyReportFilters() {
    if (_draftFilters.endDate.isBefore(_draftFilters.startDate) ||
        _draftFilters.endDate.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a valid report date range.')),
      );
      return;
    }
    ref.read(reportFiltersProvider.notifier).state = _draftFilters;
  }

  void _resetReportFilters() {
    final filters = ReportFilters.forPreset(ReportDatePreset.thisMonth);
    setState(() => _draftFilters = filters);
    ref.read(reportFiltersProvider.notifier).state = filters;
  }

  Widget _buildReportError(
    BuildContext context, {
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Unable to load report'),
          const SizedBox(height: 8),
          const Text("We couldn't retrieve the report data."),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoReportData(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.info),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No data for this period',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Try another date range or change the report filters.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _resetReportFilters,
            child: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context, ReportStats stats) {
    final kpis = [
      _KpiMetric(
        title: 'New Patients',
        subtitle: 'Registered in period',
        value: stats.newPatients.toString(),
        delta: stats.newPatientsDelta,
        icon: Icons.person_add_alt_1,
        color: AppColors.primaryEmerald,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1050
            ? 3
            : constraints.maxWidth > 700
            ? 2
            : 1;

        return Wrap(
          alignment: WrapAlignment.start,
          spacing: 12,
          runSpacing: 12,
          children: kpis.map((kpi) {
            final width =
                (constraints.maxWidth - (12 * (columns - 1))) / columns;
            return SizedBox(
              width: width,
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kpi.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(kpi.icon, color: kpi.color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kpi.title,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (kpi.subtitle != null)
                            Text(
                              kpi.subtitle!,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            kpi.value,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                kpi.delta.isPositive
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                size: 14,
                                color: kpi.delta.isPositive
                                    ? AppColors.success
                                    : AppColors.critical,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                kpi.delta.formatted,
                                style: TextStyle(
                                  color: kpi.delta.isPositive
                                      ? AppColors.success
                                      : AppColors.critical,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAnalyticsCharts(BuildContext context, ReportStats stats) {
    final newPatientTrends = stats.newPatientTrends;
    final newPatientValues = _valuesFromTrends(newPatientTrends);
    final rangeLabel = 'Grouped by ${stats.grouping.label.toLowerCase()}';

    return _buildTrendCard(
      context,
      title: 'New Patient Registrations',
      subtitle: rangeLabel,
      trends: newPatientTrends,
      values: newPatientValues,
      grouping: stats.grouping,
      lineColor: context.semanticColors.normal,
    );
  }

  Widget _buildDemographicsSection(BuildContext context, ReportStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final barangayCard = _buildDistributionCard(
          context,
          title: 'Patients by Barangay',
          metrics: stats.patientsByBarangay,
          emptyMessage: 'No barangay data recorded',
        );
        final categoryCard = _buildDistributionCard(
          context,
          title: 'Patients by Category',
          metrics: stats.patientsByCategory,
          emptyMessage: 'No category data recorded',
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: barangayCard),
              const SizedBox(width: 12),
              Expanded(child: categoryCard),
            ],
          );
        }

        return Column(
          children: [barangayCard, const SizedBox(height: 12), categoryCard],
        );
      },
    );
  }

  Widget _buildTrendCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<ReportTrend> trends,
    required List<double> values,
    required ReportGrouping grouping,
    required Color lineColor,
  }) {
    final total = trends.fold<int>(0, (sum, item) => sum + item.count);
    final average = trends.isEmpty ? 0.0 : total / trends.length;
    final startLabel = trends.isNotEmpty
        ? _formatTrendLabel(trends.first.date, grouping)
        : '';
    final endLabel = trends.isNotEmpty
        ? _formatTrendLabel(trends.last.date, grouping)
        : '';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '$subtitle · avg ${average.toStringAsFixed(1)} per period',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trends.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: lineColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: lineColor.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '$total total',
                    style: TextStyle(
                      color: lineColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: values.isEmpty
                ? Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(color: context.semanticColors.neutral),
                    ),
                  )
                : CustomPaint(
                    painter: _TrendLinePainter(
                      values: values,
                      lineColor: lineColor,
                      gridColor: AppColors.border.withValues(alpha: 0.3),
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),
          if (startLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  startLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  endLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDistributionCard(
    BuildContext context, {
    required String title,
    required List<DistributionMetric> metrics,
    required String emptyMessage,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (metrics.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  emptyMessage,
                  style: TextStyle(color: context.semanticColors.neutral),
                ),
              ),
            )
          else
            ...metrics.asMap().entries.map((entry) {
              final index = entry.key;
              final metric = entry.value;
              final maxVal = metrics.map((e) => e.value).reduce(math.max);
              final ratio = maxVal > 0 ? metric.value / maxVal : 0.0;
              final colors = [
                AppColors.info,
                AppColors.primaryEmerald,
                AppColors.warning,
                AppColors.textSecondary,
                AppColors.critical,
                AppColors.analytical,
              ];
              final color = colors[index % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            metric.label,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${metric.value}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${metric.percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: ratio,
                        backgroundColor: color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 768;
            if (!isDesktop || children.length <= 1) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              );
            }
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: children
                  .map((child) => SizedBox(width: width, child: child))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyReportsSection(BuildContext context) {
    return _buildSection(context, 'Recent Reports', [
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: context.semanticColors.neutral),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No reports generated yet. Use the options above to create your first report.',
                style: TextStyle(color: context.semanticColors.neutral),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildReportCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
        subtitle: Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 13,
          color: AppColors.textTertiary,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildRecentReportTile(
    BuildContext context,
    GeneratedReport report,
    IconData icon,
    VoidCallback onTap,
  ) {
    final isMobile = context.isMobile;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        leading: Icon(icon, color: context.semanticColors.neutral),
        title: Text(report.title),
        subtitle: Text(
          [
            'Generated on ${_formatDate(report.generatedAt)}',
            if (report.startDate != null && report.endDate != null)
              '${_formatDate(report.startDate!)} to ${_formatDate(report.endDate!)}',
          ].join(' - '),
        ),
        trailing: isMobile
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Report options',
                onSelected: (value) {
                  switch (value) {
                    case 'view':
                      onTap();
                      break;
                    case 'download':
                      _downloadReport(context, report);
                      break;
                    case 'delete':
                      _deleteReport(context, report);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: ListTile(
                      leading: Icon(Icons.visibility_outlined),
                      title: Text('View Report'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'download',
                    child: ListTile(
                      leading: Icon(Icons.download_outlined),
                      title: Text('Download'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Delete',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    tooltip: 'View',
                    onPressed: onTap,
                  ),
                  IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: 'Download',
                    onPressed: () => _downloadReport(context, report),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () => _deleteReport(context, report),
                  ),
                ],
              ),
        onTap: onTap,
      ),
    );
  }

  void _showDateRangeDialog(BuildContext context, String reportType) {
    ReportExportDialog.show(
      context,
      reportType: reportType,
      startDate: _draftFilters.startDate,
      endDate: _draftFilters.endDate,
    );
  }

  String _formatTrendLabel(DateTime date, ReportGrouping grouping) {
    return switch (grouping) {
      ReportGrouping.day => _formatDate(date),
      ReportGrouping.week => 'Week of ${_formatDate(date)}',
      ReportGrouping.month => DateFormat('MMM yyyy').format(date),
      ReportGrouping.year => '${date.year}',
    };
  }

  void _viewReport(BuildContext context, GeneratedReport report) {
    final coverage = report.startDate == null || report.endDate == null
        ? 'Not specified'
        : '${_formatDate(report.startDate!)} to ${_formatDate(report.endDate!)}';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(report.title),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report type: ${report.type}'),
              const SizedBox(height: 8),
              Text('Generated: ${formatDateTime12h(report.generatedAt)}'),
              const SizedBox(height: 8),
              Text('Coverage: $coverage'),
              if (report.filePath != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Saved location: ${report.filePath}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () => _downloadReport(context, report),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Open / Share'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              ReportExportDialog.show(
                context,
                reportType: report.type,
                startDate: report.startDate ?? _draftFilters.startDate,
                endDate: report.endDate ?? _draftFilters.endDate,
              );
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Preview & Export PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReport(
    BuildContext context,
    GeneratedReport report,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text(
          'Are you sure you want to delete this information?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(databaseProvider).deleteGeneratedReport(report.id);
    ref.invalidate(generatedReportsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report deleted')));
    }
  }

  Future<void> _downloadReport(
    BuildContext context,
    GeneratedReport report,
  ) async {
    final filePath = report.filePath;
    if (filePath == null || filePath.trim().isEmpty) {
      ReportExportDialog.show(
        context,
        reportType: report.type,
        startDate: report.startDate ?? _draftFilters.startDate,
        endDate: report.endDate ?? _draftFilters.endDate,
      );
      return;
    }

    try {
      final reportService = ReportService(ref.read(databaseProvider));
      final opened = await reportService.openExportedReport(filePath);
      if (!opened && context.mounted) {
        await reportService.shareReport(filePath);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Report opened: $filePath')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open or share report: $e')),
        );
      }
    }
  }

  Widget _buildConsultationReport(
    BuildContext context,
    AsyncValue<List<ConsultationReportEntry>> entriesAsync,
    ReportFilters filters,
  ) {
    final theme = Theme.of(context);
    final dateRange =
        '${DateFormat('MMM d, yyyy').format(filters.startDate)} – '
        '${DateFormat('MMM d, yyyy').format(filters.endDate)}';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: entriesAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stackTrace) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Unable to load patient visits.'),
            const SizedBox(height: 8),
            Text('$error'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    ref.invalidate(consultationReportEntriesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
        data: (entries) {
          final visits = filterConsultationReportEntries(
            entries: entries,
            startDate: filters.startDate,
            endDate: filters.endDate,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient Visits & Consultations',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateRange · ${visits.length} visit${visits.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: visits.isEmpty || _isExportingConsultations
                        ? null
                        : () => _exportConsultationReport(
                            context,
                            visits,
                            filters,
                          ),
                    icon: _isExportingConsultations
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      _isExportingConsultations
                          ? 'Exporting...'
                          : 'Export PDF',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (visits.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy_outlined,
                        size: 36,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('No visits in this reporting period'),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a different date range to view consultation records.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              else
                for (final entry in visits)
                  _ConsultationReportTile(entry: entry),
              const SizedBox(height: 8),
              Text(
                'Patient details are confidential. Exported PDFs are recorded in the audit log.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportConsultationReport(
    BuildContext context,
    List<ConsultationReportEntry> visits,
    ReportFilters filters,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null ||
        !user.canAccessPatientRecords ||
        !user.canGenerateReports) {
      AppNotification.error(
        title: 'Access Denied',
        message: 'You are not authorized to export patient visit reports.',
      );
      return;
    }

    setState(() => _isExportingConsultations = true);
    try {
      final db = ref.read(databaseProvider);
      final settings = await db.getSystemSettings();
      final rows = visits.map((entry) {
        final consultation = entry.consultation;
        return [
          entry.patient?.fullName ?? 'Unknown patient',
          entry.visitDate == null
              ? 'Unknown'
              : DateFormat('MMM d, yyyy').format(entry.visitDate!),
          entry.provider?.fullName ?? 'Not recorded',
          consultation.assessment?.trim().isNotEmpty == true
              ? consultation.assessment!.trim()
              : 'Not recorded',
          consultation.plan?.trim().isNotEmpty == true
              ? consultation.plan!.trim()
              : 'Not recorded',
        ];
      }).toList();
      final bytes = await const ReportPdfService()
          .generateConsultationHistoryPdf(
            startDate: filters.startDate,
            endDate: filters.endDate,
            visitRows: rows,
            settings: settings,
            preparedByName: user.fullName,
            preparedByRole: user.role.displayName,
          );
      final filename =
          'MedSentry_Patient_Visits_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      final savedPath = await ReportService(db).exportReportToPdf(
        pdfBytes: bytes,
        filename: filename,
        dialogTitle: 'Save Patient Visits Report',
      );
      if (savedPath == null) return;

      final now = DateTime.now();
      final reportId = const Uuid().v4();
      await db.insertGeneratedReport(
        GeneratedReport(
          id: reportId,
          title: 'Patient Visits - ${DateFormat('yyyy-MM-dd').format(now)}',
          type: 'Patient Visits & Consultations',
          generatedAt: now,
          startDate: filters.startDate,
          endDate: filters.endDate,
          filePath: savedPath,
        ),
      );
      ref.invalidate(generatedReportsProvider);

      try {
        await ref.read(auditServiceProvider).logAction(
          userId: user.id,
          userName: user.fullName,
          userRole: user.role.displayName,
          action: AuditAction.export,
          entityType: 'consultation_report',
          entityId: reportId,
          description:
              'Exported patient visits report for ${DateFormat('yyyy-MM-dd').format(filters.startDate)} to ${DateFormat('yyyy-MM-dd').format(filters.endDate)}',
          details: '${visits.length} consultation records; file: $filename',
        );
      } catch (error) {
        AppNotification.error(
          title: 'Audit Logging Error',
          message:
              'The PDF was saved, but the export could not be recorded in the audit log: $error',
        );
        return;
      }

      AppNotification.success(
        title: 'Report Exported',
        message: '${visits.length} visit records saved as $filename.',
      );
    } catch (error) {
      AppNotification.error(
        title: 'Report Export Error',
        message: 'Could not export patient visits: $error',
      );
    } finally {
      if (mounted) setState(() => _isExportingConsultations = false);
    }
  }

  Widget _buildTabSelector(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : theme.colorScheme.surface,
        borderRadius: AppRadius.roundedSm,
        border: Border.all(
          color: isDark
              ? AppColors.border
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Wrap(
        children: [
          _buildTabButton(
            context,
            title: 'Generated Reports Archive',
            icon: Icons.description_outlined,
            isActive: _activeTab == 'reports',
            onTap: () => setState(() => _activeTab = 'reports'),
          ),
          _buildTabButton(
            context,
            title: 'Patient Visits',
            icon: Icons.medical_information_outlined,
            isActive: _activeTab == 'visits',
            onTap: () => setState(() => _activeTab = 'visits'),
          ),
          _buildTabButton(
            context,
            title: 'Historical Audit & Activity Logs',
            icon: Icons.history_outlined,
            isActive: _activeTab == 'logs',
            onTap: () => setState(() => _activeTab = 'logs'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.roundedSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                  ? AppColors.primaryEmeraldSubtle
                  : theme.colorScheme.primary.withValues(alpha: 0.12))
              : Colors.transparent,
          borderRadius: AppRadius.roundedSm,
          border: isActive
              ? Border.all(
                  color: isDark
                      ? AppColors.primaryEmerald.withValues(alpha: 0.4)
                      : theme.colorScheme.primary.withValues(alpha: 0.4),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? (isDark
                      ? AppColors.primaryEmerald
                      : theme.colorScheme.primary)
                  : (isDark
                      ? AppColors.textSecondary
                      : theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? (isDark
                        ? AppColors.primaryEmerald
                        : theme.colorScheme.primary)
                    : (isDark
                        ? AppColors.textPrimary
                        : theme.colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratedReportsSection(
    BuildContext context,
    AsyncValue<List<GeneratedReport>> generatedReportsAsync,
  ) {
    return generatedReportsAsync.when(
      data: (allReports) {
        if (allReports.isEmpty) {
          return _buildEmptyReportsSection(context);
        }
        final query = _reportSearchQuery.trim().toLowerCase();
        var filtered = allReports.where((r) {
          final matchQuery = query.isEmpty ||
              r.title.toLowerCase().contains(query) ||
              r.type.toLowerCase().contains(query);
          final matchType = _reportTypeFilter == 'all' ||
              r.type.toLowerCase() == _reportTypeFilter.toLowerCase();
          return matchQuery && matchType;
        }).toList();

        if (_reportSortOrder == 'newest') {
          filtered.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
        } else {
          filtered.sort((a, b) => a.generatedAt.compareTo(b.generatedAt));
        }

        final distinctTypes = allReports.map((r) => r.type).toSet().toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildReportFilterBar(
              context,
              totalCount: allReports.length,
              filteredCount: filtered.length,
              types: distinctTypes,
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              _buildEmptyFilteredReports(context)
            else
              ...filtered.map(
                (report) => _buildRecentReportTile(
                  context,
                  report,
                  Icons.description_outlined,
                  () => _viewReport(context, report),
                ),
              ),
          ],
        );
      },
      loading: () => const LoadingState(),
      error: (error, stack) => _buildReportError(
        context,
        onRetry: () => ref.invalidate(generatedReportsProvider),
      ),
    );
  }

  Widget _buildReportFilterBar(
    BuildContext context, {
    required int totalCount,
    required int filteredCount,
    required List<String> types,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
            child: TextField(
              controller: _reportSearchController,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search generated reports...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondary : Colors.grey,
                ),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _reportSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _reportSearchController.clear();
                          setState(() => _reportSearchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.roundedSm,
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.border
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
              onChanged: (val) => setState(() => _reportSearchQuery = val),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (types.isNotEmpty)
                DropdownButton<String>(
                  value: _reportTypeFilter,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Types')),
                    ...types.map(
                      (t) => DropdownMenuItem(value: t, child: Text(t)),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _reportTypeFilter = val);
                  },
                ),
              DropdownButton<String>(
                value: _reportSortOrder,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                  DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _reportSortOrder = val);
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.elevatedSurface
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: AppRadius.roundedSm,
                ),
                child: Text(
                  'Showing $filteredCount of $totalCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalAuditLogsSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auditLogsAsync = ref.watch(auditLogsProvider);

    return auditLogsAsync.when(
      data: (allLogs) {
        final query = _auditSearchQuery.trim().toLowerCase();
        var filtered = allLogs.where((l) {
          final matchQuery = query.isEmpty ||
              (l.description?.toLowerCase().contains(query) ?? false) ||
              l.userId.toLowerCase().contains(query) ||
              (l.patientId?.toLowerCase().contains(query) ?? false) ||
              l.entityType.toLowerCase().contains(query);
          final matchAction = _auditActionFilter == 'all' ||
              l.action.name.toLowerCase() == _auditActionFilter.toLowerCase();
          return matchQuery && matchAction;
        }).toList();

        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(minWidth: 200, maxWidth: 320),
                    child: TextField(
                      controller: _auditSearchController,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search audit logs (actor, entity, patient ID)...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondary : Colors.grey,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _auditSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _auditSearchController.clear();
                                  setState(() => _auditSearchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.roundedSm,
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.border
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      onChanged: (val) =>
                          setState(() => _auditSearchQuery = val),
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String>(
                        value: _auditActionFilter,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Actions')),
                          DropdownMenuItem(value: 'create', child: Text('Create')),
                          DropdownMenuItem(value: 'update', child: Text('Update')),
                          DropdownMenuItem(value: 'delete', child: Text('Delete')),
                          DropdownMenuItem(value: 'export', child: Text('Export')),
                          DropdownMenuItem(value: 'login', child: Text('Login')),
                          DropdownMenuItem(value: 'sync', child: Text('Sync')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _auditActionFilter = val);
                        },
                      ),
                      IconButton(
                        tooltip: 'Refresh Logs',
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: () => ref.invalidate(auditLogsProvider),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.elevatedSurface
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: AppRadius.roundedSm,
                        ),
                        child: Text(
                          'Showing ${filtered.length} of ${allLogs.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_toggle_off,
                        size: 44,
                        color: isDark ? AppColors.textSecondary : Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No audit logs match your search or filters.',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondary
                              : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final log = filtered[index];
                  Color actionColor;
                  switch (log.action.name.toLowerCase()) {
                    case 'create':
                    case 'register':
                      actionColor = AppColors.primaryEmerald;
                      break;
                    case 'update':
                    case 'edit':
                      actionColor = AppColors.info;
                      break;
                    case 'delete':
                    case 'archive':
                      actionColor = AppColors.critical;
                      break;
                    default:
                      actionColor = AppColors.pending;
                  }

                  final dateStr =
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp);

                  return AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: actionColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: actionColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                log.action.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: actionColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '[${log.entityType.toUpperCase()}]',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : Colors.grey[700],
                              ),
                            ),
                            if (log.patientId != null &&
                                log.patientId!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                'PID: ${log.patientId}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.primaryEmerald
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          log.description ?? 'Activity recorded',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color:
                                isDark ? AppColors.textPrimary : Colors.black87,
                          ),
                        ),
                        if (log.userId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Actor: ${log.userId}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
      loading: () => const LoadingState(),
      error: (error, stack) => _buildReportError(
        context,
        onRetry: () => ref.invalidate(auditLogsProvider),
      ),
    );
  }

  Widget _buildEmptyFilteredReports(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 44,
              color: isDark ? AppColors.textSecondary : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              'No reports found matching your criteria.',
              style: TextStyle(
                color: isDark ? AppColors.textSecondary : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                _reportSearchController.clear();
                setState(() {
                  _reportSearchQuery = '';
                  _reportTypeFilter = 'all';
                });
              },
              child: const Text('Reset Filter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsultationReportTile extends StatelessWidget {
  final ConsultationReportEntry entry;

  const _ConsultationReportTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final consultation = entry.consultation;
    final visitDate = entry.visitDate;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                entry.patient?.fullName ?? 'Unknown patient',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                visitDate == null
                    ? 'Date not recorded'
                    : DateFormat('MMM d, yyyy').format(visitDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.provider?.fullName ?? 'Provider not recorded',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          if (consultation.assessment?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'Assessment',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(consultation.assessment!.trim()),
          ],
          if (consultation.plan?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              'Plan',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(consultation.plan!.trim()),
          ],
        ],
      ),
    );
  }
}

class _KpiMetric {
  final String title;
  final String? subtitle;
  final String value;
  final MetricDelta delta;
  final IconData icon;
  final Color color;

  const _KpiMetric({
    required this.title,
    this.subtitle,
    required this.value,
    required this.delta,
    required this.icon,
    required this.color,
  });
}

class _TrendLinePainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color gridColor;

  _TrendLinePainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = (maxVal - minVal).abs() < 0.001 ? 1.0 : (maxVal - minVal);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? 0.0
          : (size.width * i) / (values.length - 1);
      final normalized = (values[i] - minVal) / range;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final areaPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.03),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : (size.width * i) / (values.length - 1);
      final normalized = (values[i] - minVal) / range;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      canvas.drawCircle(Offset(x, y), 2.8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
