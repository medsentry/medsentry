import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/generated_report.dart';
import '../providers/providers.dart';
import '../services/report_service.dart';
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

  @override
  void initState() {
    super.initState();
    _draftFilters = ref.read(reportFiltersProvider);
  }

  List<double> _valuesFromTrends(List<ConsultationTrend> trends) {
    return trends.map((t) => t.count.toDouble()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(reportFiltersProvider);
    final reportStatsAsync = ref.watch(reportStatsProvider);
    final generatedReportsAsync = ref.watch(generatedReportsProvider);

    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context),
      child: ResponsiveContentContainer(
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
            'Advanced RHU operational, clinical, and compliance insights.',
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
              children: [
                if (stats.totalConsultations == 0 &&
                    stats.newPatients == 0 &&
                    stats.completedQueueVisits == 0 &&
                    stats.documentsInRange == 0) ...[
                  _buildNoReportData(context),
                  const SizedBox(height: 12),
                ],
                _buildInsightsStrip(context, stats),
                const SizedBox(height: 12),
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

          _buildSection(context, 'Daily Operations', [
            _buildReportCard(
              context,
              'Daily Consultation Report',
              'Summary of all consultations for a specific day',
              Icons.calendar_today_outlined,
              context.semanticColors.info,
              () => _showDateRangeDialog(context, 'Daily Consultation Report'),
            ),
            _buildReportCard(
              context,
              'Medication Prescriptions',
              'Prescriptions and quantities recorded for consultations',
              Icons.medication_outlined,
              context.semanticColors.neutral,
              () => _showDateRangeDialog(context, 'Medication Prescriptions'),
            ),
          ]),
          const SizedBox(height: 16),

          _buildSection(context, 'Patient & Clinical', [
            _buildReportCard(
              context,
              'Patient Statistics',
              'Patient demographics and visit statistics',
              Icons.people_outline,
              context.semanticColors.normal,
              () => _showDateRangeDialog(context, 'Patient Statistics'),
            ),
            _buildReportCard(
              context,
              'Disease Surveillance',
              'Disease patterns and ICD-10 code analysis',
              Icons.health_and_safety_outlined,
              context.semanticColors.warning,
              () => _showDateRangeDialog(context, 'Disease Surveillance'),
            ),
          ]),
          const SizedBox(height: 16),

          _buildSection(context, 'Compliance & DOH', [
            _buildReportCard(
              context,
              'DOH Report',
              'Department of Health required format',
              Icons.assignment_outlined,
              context.semanticColors.critical,
              () => _showDateRangeDialog(context, 'DOH Report'),
            ),
            _buildReportCard(
              context,
              'FHSIS Export',
              'Field Health Service Information System summary',
              Icons.fact_check_outlined,
              context.semanticColors.info,
              () => _showDateRangeDialog(context, 'FHSIS Export'),
            ),
          ]),
          const SizedBox(height: 20),

          generatedReportsAsync.when(
            data: (generatedReports) => generatedReports.isNotEmpty
                ? _buildSection(
                    context,
                    'Recent Reports',
                    generatedReports
                        .map(
                          (report) => _buildRecentReportTile(
                            context,
                            report,
                            Icons.description_outlined,
                            () => _viewReport(context, report),
                          ),
                        )
                        .toList(),
                  )
                : _buildEmptyReportsSection(context),
            loading: () => const LoadingState(),
            error: (error, stack) => _buildReportError(
              context,
              onRetry: () => ref.invalidate(generatedReportsProvider),
            ),
          ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 180,
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
              width: 150,
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
            FilledButton.icon(
              onPressed: () => ReportExportDialog.show(
                context,
                reportType: 'Daily Consultation Report',
                startDate: _draftFilters.startDate,
                endDate: _draftFilters.endDate,
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Export PDF Report'),
              style: FilledButton.styleFrom(
                backgroundColor: context.semanticColors.info,
                foregroundColor: Colors.white,
              ),
            ),
            TextButton.icon(
              onPressed: _resetReportFilters,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
          ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No data for this period'),
                  Text('Try another date range or change the report filters.'),
                ],
              ),
            ),
            TextButton(
              onPressed: _resetReportFilters,
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsStrip(BuildContext context, ReportStats stats) {
    final theme = Theme.of(context);
    final items = <({IconData icon, String label, String value, Color color})>[
      (
        icon: Icons.calendar_month_outlined,
        label: 'Peak day',
        value: stats.peakConsultationLabel != null
            ? '${stats.peakConsultationLabel} (${stats.peakConsultationCount})'
            : 'No data',
        color: context.semanticColors.info,
      ),
      (
        icon: Icons.groups_outlined,
        label: 'Queue completed',
        value: stats.completedQueueVisits.toString(),
        color: context.semanticColors.normal,
      ),
      (
        icon: Icons.folder_open_outlined,
        label: 'Documents',
        value: stats.documentsInRange.toString(),
        color: context.semanticColors.neutral,
      ),
      if (stats.patientsByBarangay.isNotEmpty)
        (
          icon: Icons.location_on_outlined,
          label: 'Top barangay',
          value:
              '${stats.patientsByBarangay.first.label} (${stats.patientsByBarangay.first.value})',
          color: context.semanticColors.warning,
        ),
    ];

    return Card(
      color: theme.colorScheme.primary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Wrap(
          spacing: 20,
          runSpacing: 10,
          children: items.map((item) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 18, color: item.color),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    Text(
                      item.value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context, ReportStats stats) {
    final kpis = [
      _KpiMetric(
        title: 'Consultations',
        subtitle: 'In selected period',
        value: stats.totalConsultations.toString(),
        delta: stats.consultationsDelta,
        icon: Icons.medical_services_outlined,
        color: context.semanticColors.info,
      ),
      _KpiMetric(
        title: 'New Patients',
        subtitle: 'Registered in period',
        value: stats.newPatients.toString(),
        delta: stats.newPatientsDelta,
        icon: Icons.person_add_alt_1,
        color: context.semanticColors.normal,
      ),
      _KpiMetric(
        title: 'Follow-ups',
        subtitle: 'Return visits',
        value: stats.followUps.toString(),
        delta: stats.followUpsDelta,
        icon: Icons.assignment_return,
        color: context.semanticColors.warning,
      ),
      _KpiMetric(
        title: 'Avg Wait Time',
        subtitle: 'Queue to service start',
        value: stats.avgWaitMinutes > 0 ? '${stats.avgWaitMinutes} min' : 'N/A',
        delta: stats.avgWaitDelta,
        icon: Icons.timer_outlined,
        color: context.semanticColors.neutral,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1050
            ? 4
            : constraints.maxWidth > 700
            ? 2
            : 1;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kpis.map((kpi) {
            final width =
                (constraints.maxWidth - (12 * (columns - 1))) / columns;
            return SizedBox(
              width: width,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: kpi.color.withValues(alpha: 0.12),
                        child: Icon(kpi.icon, color: kpi.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kpi.title,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (kpi.subtitle != null)
                              Text(
                                kpi.subtitle!,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              kpi.value,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  kpi.delta.isPositive
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 14,
                                  color: kpi.delta.isPositive
                                      ? context.semanticColors.normal
                                      : context.semanticColors.critical,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  kpi.delta.formatted,
                                  style: TextStyle(
                                    color: kpi.delta.isPositive
                                        ? context.semanticColors.normal
                                        : context.semanticColors.critical,
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
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAnalyticsCharts(BuildContext context, ReportStats stats) {
    final consultationTrends = stats.consultationTrends;
    final newPatientTrends = stats.newPatientTrends;
    final consultationValues = _valuesFromTrends(consultationTrends);
    final newPatientValues = _valuesFromTrends(newPatientTrends);
    final rangeLabel = 'Grouped by ${stats.grouping.label.toLowerCase()}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        final consultationCard = _buildTrendCard(
          context,
          title: 'Consultation Volume',
          subtitle: rangeLabel,
          trends: consultationTrends,
          values: consultationValues,
          grouping: stats.grouping,
          lineColor: Theme.of(context).colorScheme.primary,
        );

        final newPatientsCard = _buildTrendCard(
          context,
          title: 'New Patient Registrations',
          subtitle: rangeLabel,
          trends: newPatientTrends,
          values: newPatientValues,
          grouping: stats.grouping,
          lineColor: context.semanticColors.normal,
        );

        final distributionCard = _buildDistributionCard(
          context,
          title: 'Top Diagnoses (ICD-10)',
          metrics: stats.topDiagnoses,
          emptyMessage: 'No diagnosis data in this period',
        );

        if (isWide) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: consultationCard),
                  const SizedBox(width: 12),
                  Expanded(child: newPatientsCard),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: distributionCard),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            consultationCard,
            const SizedBox(height: 12),
            newPatientsCard,
            const SizedBox(height: 12),
            distributionCard,
          ],
        );
      },
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
    required List<ConsultationTrend> trends,
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.62),
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
                      color: lineColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
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
            const SizedBox(height: 8),
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
                        gridColor: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      child: const SizedBox.expand(),
                    ),
            ),
            if (startLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    startLabel,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(endLabel, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionCard(
    BuildContext context, {
    required String title,
    required List<DistributionMetric> metrics,
    required String emptyMessage,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                  context.semanticColors.info,
                  context.semanticColors.normal,
                  context.semanticColors.warning,
                  context.semanticColors.neutral,
                  context.semanticColors.critical,
                  context.semanticColors.info,
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
                              style: Theme.of(context).textTheme.bodySmall,
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 10,
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
      Card(
        child: Padding(
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to open or share report: $e')));
      }
    }
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
