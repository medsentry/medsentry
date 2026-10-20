import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/report_service.dart';
import '../utils/context_extensions.dart';
import '../utils/date_time_format.dart';
import '../utils/report_date_filter.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';
import '../widgets/report_export_dialog.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late ReportFilters _draftFilters;
  String _activeTab = 'reports'; // 'reports' or 'logs'
  String _reportSearchQuery = '';
  String _reportTypeFilter = 'all';
  String _reportSortOrder = 'newest';
  String _auditSearchQuery = '';
  String _auditActionFilter = 'all';
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
    final reportStatsAsync = ref.watch(reportStatsProvider);
    final generatedReportsAsync = ref.watch(generatedReportsProvider);

    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context),
      child: ResponsiveContentContainer(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(context, reportStatsAsync.valueOrNull),
            const SizedBox(height: 12),
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
            _buildSection(context, 'Official DOH / RHU Reports', [
              _buildReportCard(
                context,
                'Patient Statistics',
                'Patient demographics, barangay distribution, and registration trends',
                Icons.people_outline,
                context.semanticColors.normal,
                () => _showDateRangeDialog(context, 'Patient Statistics'),
              ),
              _buildReportCard(
                context,
                'Document & Registry Summary',
                'Clinical document uploads, verification metrics, and registry audit',
                Icons.folder_copy_outlined,
                context.semanticColors.info,
                () => _showDateRangeDialog(
                  context,
                  'Document & Registry Summary',
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _buildTabSelector(context),
            const SizedBox(height: 16),
            if (_activeTab == 'reports')
              _buildGeneratedReportsSection(context, generatedReportsAsync)
            else
              _buildHistoricalAuditLogsSection(context),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

  Widget _buildPageHeader(BuildContext context, ReportStats? stats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final startStr = _formatDate(_draftFilters.startDate);
    final endStr = _formatDate(_draftFilters.endDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reports & Clinical Analytics',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Text(
                  // Describes the format; compliance itself must be
                  // confirmed by the RHU / DOH, not asserted by the app.
                  'BASED ON DOH FHSIS FORMAT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.primaryEmerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Official RHU epidemiological census, morbidity metrics, and regulatory audit trail.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                ),
                child: Text(
                  'PERIOD: $startStr - $endStr',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF334155),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (stats != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${stats.newPatients} NEW PATIENTS',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppColors.primaryEmerald,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${stats.documentsInRange} DOCUMENTS RECORDED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(BuildContext context) {
    final canApply =
        !_draftFilters.endDate.isBefore(_draftFilters.startDate) &&
        !_draftFilters.endDate.isAfter(DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
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
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: dropdownWidth,
                height: 40,
                child: DropdownButtonFormField<ReportDatePreset>(
                  initialValue: _draftFilters.preset,
                  // Fixed-width field: long preset names truncate instead of
                  // overflowing.
                  isExpanded: true,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Date Range',
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                      ),
                    ),
                    isDense: true,
                  ),
                  items: ReportDatePreset.values
                      .map(
                        (preset) => DropdownMenuItem(
                          value: preset,
                          child: Text(preset.label, style: const TextStyle(fontSize: 13)),
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
              InkWell(
                onTap: _pickReportStartDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.inputSurface : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 15,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'From ${_formatDate(_draftFilters.startDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: _pickReportEndDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.inputSurface : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 15,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'To ${_formatDate(_draftFilters.endDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: groupingWidth,
                height: 40,
                child: DropdownButtonFormField<ReportGrouping>(
                  initialValue: _draftFilters.grouping,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Group By',
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                      ),
                    ),
                    isDense: true,
                  ),
                  items: ReportGrouping.values
                      .map(
                        (grouping) => DropdownMenuItem(
                          value: grouping,
                          child: Text(grouping.label, style: const TextStyle(fontSize: 13)),
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
              ElevatedButton.icon(
                onPressed: canApply ? _applyReportFilters : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.filter_alt_outlined, size: 16),
                label: const Text('Apply Filters', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              OutlinedButton.icon(
                onPressed: _resetReportFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                  side: BorderSide(color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1)),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Reset', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
          );
        },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No records found for this period',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Try selecting a wider date range or resetting filter parameters.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _resetReportFilters,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide(color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1)),
            ),
            child: const Text('Reset Filters', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context, ReportStats stats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final kpis = [
      _KpiMetric(
        title: 'New Patients',
        subtitle: 'Registered in selected period',
        value: stats.newPatients.toString(),
        delta: stats.newPatientsDelta,
        icon: Icons.person_add_alt_1_outlined,
        color: AppColors.primaryEmerald,
      ),
      _KpiMetric(
        title: 'Clinical Documents',
        subtitle: 'Uploaded in selected period',
        value: stats.documentsInRange.toString(),
        delta: stats.documentsDelta,
        icon: Icons.folder_copy_outlined,
        color: const Color(0xFF0D9488),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 700 ? 2 : 1;

        return Wrap(
          alignment: WrapAlignment.start,
          spacing: 12,
          runSpacing: 12,
          children: kpis.map((kpi) {
            final width =
                (constraints.maxWidth - (12 * (columns - 1))) / columns;
            return SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardSurface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          kpi.title.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            fontSize: 10,
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            kpi.icon,
                            size: 15,
                            color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      kpi.value,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        letterSpacing: -0.5,
                        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (kpi.delta.isPositive ? AppColors.success : AppColors.critical).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                kpi.delta.isPositive
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                size: 12,
                                color: kpi.delta.isPositive
                                    ? AppColors.success
                                    : AppColors.critical,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                kpi.delta.formatted,
                                style: TextStyle(
                                  color: kpi.delta.isPositive
                                      ? AppColors.success
                                      : AppColors.critical,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (kpi.subtitle != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              kpi.subtitle!,
                              style: TextStyle(
                                color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
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
      lineColor: AppColors.primaryEmerald,
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
          emptyMessage: 'No barangay records for selected period',
        );
        final categoryCard = _buildDistributionCard(
          context,
          title: 'Patients by Category',
          metrics: stats.patientsByCategory,
          emptyMessage: 'No patient category records for selected period',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final total = trends.fold<int>(0, (sum, item) => sum + item.count);
    final average = trends.isEmpty ? 0.0 : total / trends.length;
    final startLabel = trends.isNotEmpty
        ? _formatTrendLabel(trends.first.date, grouping)
        : '';
    final endLabel = trends.isNotEmpty
        ? _formatTrendLabel(trends.last.date, grouping)
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
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
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$subtitle · avg ${average.toStringAsFixed(1)} per period',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                        fontSize: 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (trends.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '$total TOTAL',
                    style: const TextStyle(
                      color: AppColors.primaryEmerald,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.4,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: values.isEmpty
                ? Center(
                    child: Text(
                      'No trend observations in range',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                      ),
                    ),
                  )
                : CustomPaint(
                    painter: _TrendLinePainter(
                      values: values,
                      lineColor: AppColors.primaryEmerald,
                      gridColor: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),
          if (startLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  startLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  endLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                    fontFeatures: const [FontFeature.tabularFigures()],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    // Clinical sequential density scale
    const clinicalColors = [
      AppColors.primaryEmerald, // #0F766E
      Color(0xFF0D9488),        // Teal 600
      Color(0xFF0284C7),        // Sky 600
      Color(0xFF6366F1),        // Indigo 500
      Color(0xFF64748B),        // Slate 500
      Color(0xFF334155),        // Slate 700
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          if (metrics.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  emptyMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                  ),
                ),
              ),
            )
          else
            ...metrics.asMap().entries.map((entry) {
              final index = entry.key;
              final metric = entry.value;
              final maxVal = metrics.map((e) => e.value).reduce(math.max);
              final ratio = maxVal > 0 ? metric.value / maxVal : 0.0;
              final color = clinicalColors[index % clinicalColors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            metric.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${metric.value}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${metric.percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: ratio,
                        backgroundColor: isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildSection(context, 'Recent Reports', [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardSurface : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No reports generated yet. Use the options above to create your first report.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardSurface : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: -0.2,
                      color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isDark ? AppColors.textSecondary : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentReportTile(
    BuildContext context,
    GeneratedReport report,
    IconData icon,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = context.isMobile;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    'Generated on ${_formatDate(report.generatedAt)}',
                    if (report.startDate != null && report.endDate != null)
                      '${_formatDate(report.startDate!)} to ${_formatDate(report.endDate!)}',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (isMobile)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 18,
                color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
              ),
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
                    leading: Icon(Icons.visibility_outlined, size: 18),
                    title: Text('View Details', style: TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'download',
                  child: ListTile(
                    leading: Icon(Icons.download_outlined, size: 18),
                    title: Text('Open / Export', style: TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  tooltip: 'View Details',
                  color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                  onPressed: onTap,
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined, size: 16),
                  tooltip: 'Open / Export',
                  color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                  onPressed: () => _downloadReport(context, report),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  tooltip: 'Delete',
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                  onPressed: () => _deleteReport(context, report),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showDateRangeDialog(BuildContext context, String reportType) {
    final appliedFilters = ref.read(reportFiltersProvider);
    ReportExportDialog.show(
      context,
      reportType: reportType,
      startDate: appliedFilters.startDate,
      endDate: appliedFilters.endDate,
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
    final appliedFilters = ref.read(reportFiltersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AppFormDialog(
        title: report.title,
        subtitle: 'Generated Report Details',
        icon: Icons.description_outlined,
        maxWidth: 500,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.inputSurface : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReportInfoRow(context, 'Report type', report.type),
                  const Divider(height: 16),
                  _buildReportInfoRow(
                    context,
                    'Generated',
                    formatDateTime12h(report.generatedAt),
                  ),
                  const Divider(height: 16),
                  _buildReportInfoRow(context, 'Coverage', coverage),
                  if (report.filePath != null) ...[
                    const Divider(height: 16),
                    _buildReportInfoRow(
                      context,
                      'Saved location',
                      report.filePath!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () => _downloadReport(context, report),
            icon: const Icon(Icons.share_outlined, size: 16),
            label: const Text('Open / Share'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              ReportExportDialog.show(
                context,
                reportType: report.type,
                startDate: report.startDate ?? appliedFilters.startDate,
                endDate: report.endDate ?? appliedFilters.endDate,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: const Text('Preview & Export PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteReport(
    BuildContext context,
    GeneratedReport report,
  ) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Delete Report',
      message:
          'Are you sure you want to delete "${report.title}" from the archive? This action cannot be undone.',
      confirmLabel: 'Delete Report',
      cancelLabel: 'Cancel',
      type: ConfirmDialogType.danger,
      isDestructive: true,
      icon: Icons.delete_outline,
    );

    if (confirmed != true) return;

    await ref.read(databaseProvider).deleteGeneratedReport(report.id);
    await ref
        .read(auditServiceProvider)
        .logAction(
          action: AuditAction.delete,
          entityType: AuditEntityTypes.report,
          entityId: report.id,
          details: 'Deleted generated report "${report.title}"',
        );
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
    final appliedFilters = ref.read(reportFiltersProvider);
    if (filePath == null || filePath.trim().isEmpty) {
      ReportExportDialog.show(
        context,
        reportType: report.type,
        startDate: report.startDate ?? appliedFilters.startDate,
        endDate: report.endDate ?? appliedFilters.endDate,
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

  Widget _buildTabSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? AppColors.elevatedSurface : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(
                  color: isDark
                      ? AppColors.primaryEmerald.withValues(alpha: 0.4)
                      : const Color(0xFFCBD5E1),
                  width: 1,
                )
              : null,
          boxShadow: isActive && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive
                  ? AppColors.primaryEmerald
                  : (isDark
                        ? AppColors.textSecondary
                        : const Color(0xFF64748B)),
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
                          : const Color(0xFF0F766E))
                    : (isDark
                          ? AppColors.textSecondary
                          : const Color(0xFF64748B)),
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
      skipLoadingOnReload: true,
      data: (allReports) {
        if (allReports.isEmpty) {
          return _buildEmptyReportsSection(context);
        }
        final distinctTypes = allReports.map((r) => r.type).toSet().toList();
        final activeTypeFilter =
            (_reportTypeFilter == 'all' ||
                distinctTypes.contains(_reportTypeFilter))
            ? _reportTypeFilter
            : 'all';

        final query = _reportSearchQuery.trim().toLowerCase();
        var filtered = allReports.where((r) {
          final matchQuery =
              query.isEmpty ||
              r.title.toLowerCase().contains(query) ||
              r.type.toLowerCase().contains(query);
          final matchType =
              activeTypeFilter == 'all' ||
              r.type.toLowerCase() == activeTypeFilter.toLowerCase();
          return matchQuery && matchType;
        }).toList();

        if (_reportSortOrder == 'newest') {
          filtered.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
        } else {
          filtered.sort((a, b) => a.generatedAt.compareTo(b.generatedAt));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildReportFilterBar(
              context,
              totalCount: allReports.length,
              filteredCount: filtered.length,
              types: distinctTypes,
              activeTypeFilter: activeTypeFilter,
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
    required String activeTypeFilter,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _reportSearchController,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search generated reports...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF94A3B8),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 16,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                  ),
                  suffixIcon: _reportSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _reportSearchController.clear();
                            setState(() => _reportSearchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                onChanged: (val) => setState(() => _reportSearchQuery = val),
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (types.isNotEmpty)
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.inputSurface : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: activeTypeFilter,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Types'),
                        ),
                        ...types.map(
                          (t) => DropdownMenuItem(value: t, child: Text(t)),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _reportTypeFilter = val);
                      },
                    ),
                  ),
                ),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.inputSurface : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _reportSortOrder,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'newest',
                        child: Text('Newest First'),
                      ),
                      DropdownMenuItem(
                        value: 'oldest',
                        child: Text('Oldest First'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _reportSortOrder = val);
                    },
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Showing $filteredCount of $totalCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auditLogsAsync = ref.watch(auditLogsProvider);

    return auditLogsAsync.when(
      skipLoadingOnReload: true,
      data: (allLogs) {
        final query = _auditSearchQuery.trim().toLowerCase();
        var filtered = allLogs.where((l) {
          final matchQuery =
              query.isEmpty ||
              (l.description?.toLowerCase().contains(query) ?? false) ||
              (l.details?.toLowerCase().contains(query) ?? false) ||
              (l.userName?.toLowerCase().contains(query) ?? false) ||
              l.userId.toLowerCase().contains(query) ||
              (l.patientId?.toLowerCase().contains(query) ?? false) ||
              l.entityType.toLowerCase().contains(query);
          final matchAction =
              _auditActionFilter == 'all' ||
              l.action.name.toLowerCase() == _auditActionFilter.toLowerCase();
          return matchQuery && matchAction;
        }).toList();

        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardSurface : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 200,
                      maxWidth: 320,
                    ),
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _auditSearchController,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText:
                              'Search audit logs (actor, entity, patient ID)...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textSecondary : const Color(0xFF94A3B8),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 16,
                            color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                          ),
                          suffixIcon: _auditSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14),
                                  onPressed: () {
                                    _auditSearchController.clear();
                                    setState(() => _auditSearchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        onChanged: (val) =>
                            setState(() => _auditSearchQuery = val),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.inputSurface : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _auditActionFilter,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('All Actions'),
                              ),
                              ...AuditAction.values.map(
                                (action) => DropdownMenuItem(
                                  value: action.name,
                                  child: Text(action.displayName),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _auditActionFilter = val);
                              }
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh Logs',
                        icon: Icon(
                          Icons.refresh,
                          size: 16,
                          color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                        ),
                        onPressed: () => ref.invalidate(auditLogsProvider),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.inputSurface : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Showing ${filtered.length} of ${allLogs.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
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
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardSurface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_toggle_off,
                        size: 36,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No audit logs match your search or filters.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
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
                    case 'restore':
                      actionColor = AppColors.primaryEmerald;
                      break;
                    case 'update':
                      actionColor = const Color(0xFF0284C7);
                      break;
                    case 'delete':
                    case 'archive':
                      actionColor = AppColors.critical;
                      break;
                    default:
                      actionColor = const Color(0xFF64748B);
                  }

                  final dateStr = formatDateTime12h(log.timestamp);
                  final actorLabel = log.userName?.isNotEmpty == true
                      ? '${log.userName} (${log.userRole ?? log.userId})'
                      : log.userId;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardSurface : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
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
                                color: actionColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: actionColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                log.action.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
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
                                color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                              ),
                            ),
                            if (log.patientId != null &&
                                log.patientId!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                'PID: ${log.patientId}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryEmerald,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          log.description ?? log.details ?? 'Activity recorded',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                          ),
                        ),
                        if (actorLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Actor: $actorLabel',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
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

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 36,
              color: isDark ? AppColors.textSecondary : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 10),
            Text(
              'No reports found matching your criteria.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
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
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                side: BorderSide(color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1)),
              ),
              child: const Text('Reset Filter', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
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
      ..strokeWidth = 2.0
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
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
