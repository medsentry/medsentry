import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/generated_report.dart';
import '../providers/providers.dart';
import '../services/report_service.dart';
import '../widgets/loading_state.dart';
import '../utils/context_extensions.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  List<ConsultationTrend> _trendsForRange(
    List<ConsultationTrend> trends,
    int rangeDays,
  ) {
    if (trends.isEmpty) return trends;
    final startIndex = math.max(0, trends.length - rangeDays);
    return trends.sublist(startIndex);
  }

  List<double> _valuesFromTrends(List<ConsultationTrend> trends) {
    return trends.map((t) => t.count.toDouble()).toList();
  }

  String _rangeLabel(int days) => '${days}D';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rangeDays = ref.watch(reportRangeDaysProvider);
    final reportStatsAsync = ref.watch(reportStatsProvider);
    final generatedReportsAsync = ref.watch(generatedReportsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
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

          _buildRangeSelector(context, rangeDays),
          const SizedBox(height: 12),

          reportStatsAsync.when(
            skipLoadingOnReload: true,
            data: (stats) => Column(
              children: [
                _buildInsightsStrip(context, stats),
                const SizedBox(height: 12),
                _buildKpiGrid(context, stats),
                const SizedBox(height: 16),
                _buildAnalyticsCharts(context, stats, rangeDays),
                const SizedBox(height: 16),
                _buildDemographicsSection(context, stats),
              ],
            ),
            loading: () => const LoadingState(),
            error: (error, stack) => Text('Error loading stats: $error'),
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
              'Medicine Dispensing',
              'Medicines dispensed and inventory report',
              Icons.medication_outlined,
              context.semanticColors.neutral,
              () => _showDateRangeDialog(context, 'Medicine Dispensing'),
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
            error: (error, stack) => Text('Unable to load reports: $error'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildRangeSelector(BuildContext context, int rangeDays) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 Days')),
            ButtonSegment(value: 30, label: Text('30 Days')),
            ButtonSegment(value: 90, label: Text('90 Days')),
          ],
          selected: {rangeDays},
          onSelectionChanged: (Set<int> newSelection) {
            ref.read(reportRangeDaysProvider.notifier).state =
                newSelection.first;
          },
          style: ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Comparing last $rangeDays days vs prior $rangeDays days',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
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
        subtitle: 'Last ${stats.rangeDays} days',
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

  Widget _buildAnalyticsCharts(
    BuildContext context,
    ReportStats stats,
    int rangeDays,
  ) {
    final consultationTrends = _trendsForRange(
      stats.consultationTrends,
      rangeDays,
    );
    final newPatientTrends = _trendsForRange(stats.newPatientTrends, rangeDays);
    final consultationValues = _valuesFromTrends(consultationTrends);
    final newPatientValues = _valuesFromTrends(newPatientTrends);
    final rangeLabel = _rangeLabel(rangeDays);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        final consultationCard = _buildTrendCard(
          context,
          title: 'Consultation Volume',
          subtitle: rangeLabel,
          trends: consultationTrends,
          values: consultationValues,
          lineColor: Theme.of(context).colorScheme.primary,
        );

        final newPatientsCard = _buildTrendCard(
          context,
          title: 'New Patient Registrations',
          subtitle: rangeLabel,
          trends: newPatientTrends,
          values: newPatientValues,
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
    required Color lineColor,
  }) {
    final total = trends.fold<int>(0, (sum, item) => sum + item.count);
    final average = trends.isEmpty ? 0.0 : total / trends.length;
    final startLabel = trends.isNotEmpty
        ? _formatShortDate(trends.first.date)
        : '';
    final endLabel = trends.isNotEmpty
        ? _formatShortDate(trends.last.date)
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
                        '$subtitle · avg ${average.toStringAsFixed(1)}/day',
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

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
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
        ...children,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(report.title),
        subtitle: Text(
          [
            'Generated on ${_formatDate(report.generatedAt)}',
            if (report.startDate != null && report.endDate != null)
              '${_formatDate(report.startDate!)} to ${_formatDate(report.endDate!)}',
          ].join(' - '),
        ),
        trailing: Row(
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
    final now = DateTime.now();
    var startDate = DateTime(now.year, now.month, now.day);
    var endDate = startDate;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Generate $reportType'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Start Date'),
                subtitle: Text(_formatDate(startDate)),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime(2020),
                    lastDate: now,
                  );
                  if (selected == null) return;
                  setDialogState(() {
                    startDate = selected;
                    if (endDate.isBefore(startDate)) endDate = startDate;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_available_outlined),
                title: const Text('End Date'),
                subtitle: Text(_formatDate(endDate)),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: endDate.isBefore(startDate)
                        ? startDate
                        : endDate,
                    firstDate: startDate,
                    lastDate: now,
                  );
                  if (selected == null) return;
                  setDialogState(() => endDate = selected);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _generateReport(
                  context,
                  reportType,
                  startDate: startDate,
                  endDate: endDate,
                );
              },
              icon: const Icon(Icons.add_chart_outlined),
              label: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateReport(
    BuildContext context,
    String reportType, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating report...'),
          ],
        ),
      ),
    );

    try {
      final reportData = await _buildReportData(reportType, startDate, endDate);
      final now = DateTime.now();
      final reportId = const Uuid().v4();
      final title = '$reportType - ${_formatDate(now)}';
      final filename = '${_safeFileName(title)}_$reportId.json';
      final filePath = await ReportService(
        ref.read(databaseProvider),
      ).exportReportToJson(reportData, filename: filename);

      final newReport = GeneratedReport(
        id: reportId,
        title: title,
        type: reportType,
        generatedAt: now,
        startDate: startDate,
        endDate: endDate,
        filePath: filePath,
      );
      await ref.read(databaseProvider).insertGeneratedReport(newReport);
      ref.invalidate(generatedReportsProvider);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$reportType generated successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to generate report: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _buildReportData(
    String reportType,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final service = ReportService(ref.read(databaseProvider));
    final inclusiveEnd = endDate.add(const Duration(days: 1));

    switch (reportType) {
      case 'Disease Surveillance':
        return service.generateDiseaseSurveillanceReport(
          startDate: startDate,
          endDate: inclusiveEnd,
        );
      case 'Patient Statistics':
      case 'Daily Consultation Report':
      case 'DOH Report':
      case 'Medicine Dispensing':
      default:
        final stats = await ref.read(reportStatsProvider.future);
        return {
          'report_type': reportType,
          'period': {
            'start_date': startDate.toIso8601String(),
            'end_date': inclusiveEnd.toIso8601String(),
          },
          'total_consultations': stats.totalConsultations,
          'new_patients': stats.newPatients,
          'follow_ups': stats.followUps,
          'average_wait_minutes': stats.avgWaitMinutes,
          'top_diagnoses': stats.topDiagnoses
              .map(
                (item) => {
                  'label': item.label,
                  'value': item.value,
                  'percentage': item.percentage,
                },
              )
              .toList(),
          'generated_at': DateTime.now().toIso8601String(),
        };
    }
  }

  void _viewReport(BuildContext context, GeneratedReport report) {
    final reportStatsAsync = ref.read(reportStatsProvider);

    reportStatsAsync.when(
      data: (stats) {
        final rangeDays = ref.read(reportRangeDaysProvider);
        final trendData = _valuesFromTrends(
          _trendsForRange(stats.consultationTrends, rangeDays),
        );

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(report.title),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.08),
                    ),
                    child: trendData.isNotEmpty
                        ? CustomPaint(
                            painter: _TrendLinePainter(
                              values: trendData.take(12).toList(),
                              lineColor: Theme.of(context).colorScheme.primary,
                              gridColor: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          )
                        : Center(
                            child: Text(
                              'No trend data available',
                              style: TextStyle(
                                color: context.semanticColors.neutral,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Coverage: ${report.startDate == null || report.endDate == null ? 'Not specified' : '${_formatDate(report.startDate!)} to ${_formatDate(report.endDate!)}'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Insights',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (stats.topDiagnoses.isNotEmpty) ...[
                    Text('• Top diagnosis: ${stats.topDiagnoses.first.label}'),
                    Text('• Total consultations: ${stats.totalConsultations}'),
                    Text('• New patients: ${stats.newPatients}'),
                  ] else
                    const Text('• No consultation data available yet.'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () => _downloadReport(context, report),
                icon: const Icon(Icons.download),
                label: const Text('Download PDF'),
              ),
            ],
          ),
        );
      },
      loading: () {},
      error: (_, _) {},
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No exported file is available.')),
      );
      return;
    }

    try {
      await ReportService(ref.read(databaseProvider)).shareReport(filePath);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Report ready: $filePath')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to share report: $e')));
      }
    }
  }

  String _safeFileName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
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
