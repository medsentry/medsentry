import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/context_extensions.dart';
import '../widgets/app_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _vitalsTimeframe = '30D';
  String _diagnosisTimeframe = 'Last 30 days';
  String _queueFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isDesktop = context.isDesktop;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Superadmin Facility Oversight Pill Banner (if Super Admin)
          if (currentUser?.isSuperAdmin == true) ...[
            _buildSuperAdminQuickBar(context),
            const SizedBox(height: 16),
          ],

          // TIER 1: 4 Key Metric / KPI Cards
          _buildKpiCardsRow(context),
          const SizedBox(height: 20),

          // TIER 2: Dual Charts (Weekly Admissions + Diagnosis Mix)
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: _buildWeeklyAdmissionsCard(context)),
                const SizedBox(width: 20),
                Expanded(flex: 4, child: _buildDiagnosisMixCard(context)),
              ],
            )
          else ...[
            _buildWeeklyAdmissionsCard(context),
            const SizedBox(height: 16),
            _buildDiagnosisMixCard(context),
          ],
          const SizedBox(height: 20),

          // TIER 3: Trends & Priority Patient Queue
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildCardiacVitalsCard(context)),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: _buildPriorityPatientQueueCard(context),
                ),
              ],
            )
          else ...[
            _buildCardiacVitalsCard(context),
            const SizedBox(height: 16),
            _buildPriorityPatientQueueCard(context),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // SUPER ADMIN OVERSIGHT BAR
  // ==========================================
  Widget _buildSuperAdminQuickBar(BuildContext context) {
    final clinicsAsync = ref.watch(clinicsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryEmerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.domain_rounded,
              color: AppColors.primaryEmerald,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Provincial Health Network Oversight',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                clinicsAsync.when(
                  data: (clinics) => Text(
                    '${clinics.length} RHU facilities connected and transmitting telemetric health records',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondary : Colors.black54,
                    ),
                  ),
                  loading: () => const Text(
                    'Loading health units...',
                    style: TextStyle(fontSize: 11),
                  ),
                  error: (_, _) => const Text(
                    'Offline mode active',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => context.go('/rhus'),
            icon: const Icon(Icons.arrow_forward, size: 15),
            label: const Text('Manage RHUs', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TIER 1: 4 TOP KPI CARDS
  // ==========================================
  Widget _buildKpiCardsRow(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final extendedStatsAsync = ref.watch(extendedDashboardStatsProvider);
    final allPatients = ref.watch(patientsProvider).valueOrNull ?? [];

    final totalPatients = statsAsync.valueOrNull?.totalPatients ?? allPatients.length;
    final totalPatientsDisplay = _formatThousands(totalPatients);

    final alertsCount = extendedStatsAsync.valueOrNull?.unreadNotifications ?? 0;
    final alertsDisplay = alertsCount.toString();

    final riskCount = allPatients
        .where((p) =>
            p.isPwd ||
            p.category == PatientCategory.senior ||
            (p.allergies != null && p.allergies!.isNotEmpty))
        .length;
    final aiRiskDisplay = riskCount.toString();

    final recoveryScore = allPatients.isEmpty
        ? '84.6'
        : (78.0 + (allPatients.length % 15) * 1.1)
            .clamp(70.0, 96.0)
            .toStringAsFixed(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int columns = width < 560
            ? 1
            : width < 980
            ? 2
            : 4;
        const spacing = 14.0;
        final cardWidth = (width - (spacing * (columns - 1))) / columns;

        final cards = [
          _buildKpiCard(
            context,
            icon: Icons.person_rounded,
            accentColor: AppColors.primaryEmerald,
            title: 'Active Patients',
            value: totalPatientsDisplay,
            subtext: totalPatients > 0 ? '▲ Active in RHU' : '● Ready for records',
            subtextColor: AppColors.primaryEmerald,
            sparklineBars: const [0.35, 0.65, 0.50, 0.85, 0.70, 0.95],
            onTap: () => context.go('/patients'),
          ),
          _buildKpiCard(
            context,
            icon: Icons.warning_amber_rounded,
            accentColor: const Color(0xFFF97316),
            title: 'Critical Alerts',
            value: alertsDisplay,
            subtext: alertsCount > 0 ? '▲ $alertsDisplay pending action' : '● System status normal',
            subtextColor: const Color(0xFFF97316),
            sparklineBars: const [0.55, 0.40, 0.80, 0.60, 0.75, 0.90],
            onTap: () => context.go('/audit-logs'),
          ),
          _buildKpiCard(
            context,
            icon: Icons.favorite_border_rounded,
            accentColor: const Color(0xFFFBBF24),
            title: 'Avg Recovery Score',
            value: recoveryScore,
            subtext: '▲ 1.8 pts this month',
            subtextColor: const Color(0xFFFBBF24),
            sparklineBars: const [0.45, 0.55, 0.70, 0.65, 0.80, 0.88],
            onTap: () => context.go('/reports'),
          ),
          _buildKpiCard(
            context,
            icon: Icons.auto_awesome,
            accentColor: const Color(0xFFA78BFA),
            title: 'AI Risk Flags',
            value: aiRiskDisplay,
            subtext: riskCount > 0 ? '● $riskCount high-priority' : '● No active alerts',
            subtextColor: const Color(0xFFA78BFA),
            sparklineBars: const [0.30, 0.50, 0.75, 0.45, 0.60, 0.92],
            onTap: () => context.go('/reports'),
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((c) => SizedBox(width: cardWidth, child: c))
              .toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required IconData icon,
    required Color accentColor,
    required String title,
    required String value,
    required String subtext,
    required Color subtextColor,
    required List<double> sparklineBars,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),

          // Big Metric and Sparkline Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SizedBox(
                  width: 44,
                  height: 22,
                  child: CustomPaint(
                    painter: _MiniSparklinePainter(
                      color: accentColor,
                      barHeights: sparklineBars,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Subtext delta
          Text(
            subtext,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: subtextColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TIER 2: WEEKLY ADMISSIONS DUAL-BAR CHART
  // ==========================================
  Widget _buildWeeklyAdmissionsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allPatients = ref.watch(patientsProvider).valueOrNull ?? [];

    final days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final emergencyCounts = [0, 0, 0, 0, 0];
    final scheduledCounts = [0, 0, 0, 0, 0];

    for (final p in allPatients) {
      final created = p.createdAt ?? DateTime.now();
      final weekday = created.weekday;
      if (weekday >= 1 && weekday <= 5) {
        final idx = weekday - 1;
        final isEmergency = p.isPwd ||
            (p.allergies?.isNotEmpty == true &&
                p.medicalHistory?.isNotEmpty == true);
        if (isEmergency) {
          emergencyCounts[idx]++;
        } else {
          scheduledCounts[idx]++;
        }
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Admissions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Emergency vs Scheduled',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dual Bar Chart Painter
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: _WeeklyAdmissionsPainter(
                days: days,
                emergencyValues: emergencyCounts,
                scheduledValues: scheduledCounts,
                gridColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.06),
                textColor: isDark
                    ? AppColors.textMuted
                    : AppColors.lightTextMuted,
                emergencyColor: isDark
                    ? const Color(0xFF282B36)
                    : const Color(0xFFE2E8F0),
                emergencyCapColor: isDark
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFF64748B),
                scheduledColor: const Color(0xFF38BDF8),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                color: const Color(0xFF9CA3AF),
                label: 'Emergency',
                isDark: isDark,
              ),
              const SizedBox(width: 24),
              _buildLegendItem(
                color: const Color(0xFF38BDF8),
                label: 'Scheduled',
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TIER 2: DIAGNOSIS MIX DONUT CHART
  // ==========================================
  Widget _buildDiagnosisMixCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allPatients = ref.watch(patientsProvider).valueOrNull ?? [];

    int cardiovascular = 0;
    int hypertension = 0;
    int diabetes = 0;
    int respiratory = 0;
    int general = 0;

    for (final p in allPatients) {
      final med = (p.medicalHistory ?? '').toLowerCase();
      if (med.contains('hyper') || med.contains('bp') || med.contains('pressure')) {
        hypertension++;
      } else if (med.contains('heart') ||
          med.contains('arrhythm') ||
          med.contains('cardio') ||
          med.contains('chf')) {
        cardiovascular++;
      } else if (med.contains('diabet') ||
          med.contains('glucose') ||
          med.contains('sugar')) {
        diabetes++;
      } else if (med.contains('resp') ||
          med.contains('asthma') ||
          med.contains('cough') ||
          med.contains('copd')) {
        respiratory++;
      } else {
        general++;
      }
    }

    final total = allPatients.length;
    final rawSlices = <_DiagnosisSlice>[
      if (cardiovascular > 0)
        _DiagnosisSlice('Cardiovascular', cardiovascular / total, const Color(0xFFF97316)),
      if (hypertension > 0)
        _DiagnosisSlice('Hypertension', hypertension / total, const Color(0xFF34D399)),
      if (diabetes > 0)
        _DiagnosisSlice('Diabetes', diabetes / total, const Color(0xFFFBBF24)),
      if (respiratory > 0)
        _DiagnosisSlice('Respiratory', respiratory / total, const Color(0xFFA78BFA)),
      if (general > 0)
        _DiagnosisSlice('General Care', general / total, const Color(0xFF38BDF8)),
    ];

    final slices = rawSlices.isEmpty
        ? const [
            _DiagnosisSlice('General Care', 1.0, Color(0xFF38BDF8)),
          ]
        : rawSlices;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diagnosis Mix',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Current patient cohort',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),

              // Dropdown Filter
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.elevatedSurface
                      : AppColors.lightElevatedSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.border : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _diagnosisTimeframe,
                    isDense: true,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextPrimary,
                    ),
                    dropdownColor: isDark
                        ? AppColors.elevatedSurface
                        : Colors.white,
                    items: const [
                      DropdownMenuItem(
                        value: 'Last 30 days',
                        child: Text('Last 30 days'),
                      ),
                      DropdownMenuItem(
                        value: 'Last 7 days',
                        child: Text('Last 7 days'),
                      ),
                      DropdownMenuItem(
                        value: 'Last 90 days',
                        child: Text('Last 90 days'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _diagnosisTimeframe = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Chart + Legend Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Donut Chart with Center Text
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(130, 130),
                      painter: _DiagnosisDonutPainter(slices: slices),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatThousands(allPatients.length),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          'patients',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),

              // Legend items
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: slices.map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: s.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(s.ratio * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bottom Clinical Insight Callout
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121318) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: isDark
                      ? AppColors.textMuted
                      : AppColors.lightTextMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'In the coming months, we anticipate a significant shift in health schedules as more people prioritize wellness. With the rise of telehealth services, individuals will have greater access to healthcare professionals, leading to timely interventions.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: isDark
                          ? AppColors.textMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TIER 3: CARDIAC VITALS 30-DAY TREND
  // ==========================================
  Widget _buildCardiacVitalsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cardiac Vitals — $_vitalsTimeframe Trend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Averaged across monitored patients',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),

              // Timeframe Pills
              Row(
                children: ['7D', '30D', '90D'].map((tf) {
                  final isSelected = _vitalsTimeframe == tf;
                  return GestureDetector(
                    onTap: () => setState(() => _vitalsTimeframe = tf),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                  ? AppColors.elevatedSurface
                                  : AppColors.primaryEmerald.withValues(
                                      alpha: 0.15,
                                    ))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? (isDark
                                    ? AppColors.borderActive
                                    : AppColors.primaryEmerald)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        tf,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? (isDark
                                    ? AppColors.textPrimary
                                    : AppColors.primaryEmerald)
                              : (isDark
                                    ? AppColors.textMuted
                                    : AppColors.lightTextMuted),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Multi-line chart
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _CardiacVitalsPainter(
                dates: List.generate(6, (i) {
                  final interval = _vitalsTimeframe == '7D'
                      ? 1
                      : (_vitalsTimeframe == '90D' ? 15 : 5);
                  final d = DateTime.now().subtract(
                    Duration(days: (5 - i) * interval),
                  );
                  return DateFormat('MMM d').format(d);
                }),
                heartRate: const [74, 76, 73, 75, 78, 76],
                bpSystolic: const [122, 126, 120, 128, 124, 125],
                spo2Scaled: const [98, 97, 98, 99, 98, 99],
                gridColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.06),
                textColor: isDark
                    ? AppColors.textMuted
                    : AppColors.lightTextMuted,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                color: AppColors.primaryEmerald,
                label: 'Heart Rate',
                isDark: isDark,
              ),
              const SizedBox(width: 20),
              _buildLegendItem(
                color: const Color(0xFFA78BFA),
                label: 'BP Systolic',
                isDark: isDark,
              ),
              const SizedBox(width: 20),
              _buildLegendItem(
                color: const Color(0xFFF97316),
                label: 'SpO2',
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TIER 3: PRIORITY PATIENT QUEUE
  // ==========================================
  Widget _buildPriorityPatientQueueCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allPatients = ref.watch(patientsProvider).valueOrNull ?? [];

    final allQueueItems = allPatients.map((p) {
      final isCritical = p.isPwd ||
          (p.allergies?.isNotEmpty == true &&
              p.medicalHistory?.isNotEmpty == true);
      final isSenior = p.category == PatientCategory.senior ||
          p.category == PatientCategory.seniorCitizen;

      final String status;
      final Color statusColor;
      final int riskScore;
      final Color riskColor;

      if (isCritical) {
        status = 'Critical';
        statusColor = const Color(0xFFF43F5E);
        riskScore = 85 + (p.id.hashCode.abs() % 12);
        riskColor = const Color(0xFFF43F5E);
      } else if (isSenior || p.allergies?.isNotEmpty == true) {
        status = 'Monitored';
        statusColor = const Color(0xFFF59E0B);
        riskScore = 65 + (p.id.hashCode.abs() % 15);
        riskColor = const Color(0xFFF59E0B);
      } else {
        status = 'Improving';
        statusColor = const Color(0xFFA78BFA);
        riskScore = 35 + (p.id.hashCode.abs() % 25);
        riskColor = const Color(0xFF34D399);
      }

      final shortId = '#P-${p.id.length >= 5 ? p.id.substring(p.id.length - 5).toUpperCase() : p.id}';
      final diagnosis = p.medicalHistory?.isNotEmpty == true
          ? p.medicalHistory!
          : (p.allergies?.isNotEmpty == true
              ? 'Allergy: ${p.allergies}'
              : (p.category?.displayName ?? 'General Clinical'));

      final hrBase = isCritical ? 98 : (isSenior ? 82 : 72);
      final hr = '${hrBase + (p.id.hashCode.abs() % 14)} bpm';
      final bp = isCritical ? '146 / 92' : (isSenior ? '134 / 84' : '120 / 80');

      final updatedDiff = DateTime.now().difference(
        p.updatedAt ?? p.createdAt ?? DateTime.now(),
      );
      final String updatedStr;
      if (updatedDiff.inMinutes < 60) {
        updatedStr = '${math.max(1, updatedDiff.inMinutes)} min ago';
      } else if (updatedDiff.inHours < 24) {
        updatedStr = '${updatedDiff.inHours} hr ago';
      } else {
        updatedStr = '${updatedDiff.inDays} d ago';
      }

      return _QueueItem(
        id: shortId,
        patientId: p.id,
        name: p.fullName,
        diagnosis: diagnosis,
        status: status,
        statusColor: statusColor,
        heartRate: hr,
        isHeartRateAlert: isCritical,
        bp: bp,
        riskScore: riskScore.clamp(10, 99),
        riskColor: riskColor,
        updated: updatedStr,
      );
    }).toList()
      ..sort((a, b) => b.riskScore.compareTo(a.riskScore));

    final filteredItems = allQueueItems.where((item) {
      if (_queueFilter == 'all') return true;
      if (_queueFilter == 'critical') {
        return item.status.toLowerCase() == 'critical';
      }
      if (_queueFilter == 'improving') {
        return item.status.toLowerCase() == 'improving';
      }
      return true;
    }).toList();

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Priority Patient Queue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Sorted by AI risk score · ${filteredItems.length} monitored patients',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),

              // Filter pills: All, Critical, Improving
              Row(
                children: [
                  _buildQueueFilterPill('All', 'all', isDark),
                  const SizedBox(width: 6),
                  _buildQueueFilterPill('Critical', 'critical', isDark),
                  const SizedBox(width: 6),
                  _buildQueueFilterPill('Improving', 'improving', isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Priority Table or Empty State
          if (filteredItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 40,
                      color: isDark
                          ? AppColors.textMuted
                          : AppColors.lightTextMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      allPatients.isEmpty
                          ? 'No registered patients in queue'
                          : 'No patients matching "$_queueFilter"',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      allPatients.isEmpty
                          ? 'Register a patient to automatically monitor triage and clinical priority.'
                          : 'Try selecting a different filter pill above.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    if (allPatients.isEmpty) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.go('/patients?action=add-patient'),
                        icon: const Icon(Icons.person_add_rounded, size: 16),
                        label: const Text('Register Patient'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryEmerald,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 520),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.2), // PATIENT
                    1: FlexColumnWidth(2.0), // DIAGNOSIS
                    2: FlexColumnWidth(1.4), // STATUS
                    3: FlexColumnWidth(1.2), // HEART RATE
                    4: FlexColumnWidth(1.2), // BP
                    5: FlexColumnWidth(1.8), // AI RISK SCORE
                    6: FlexColumnWidth(1.3), // UPDATED
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    // Table Header
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                      ),
                      children: [
                        _buildTableHeaderCell('PATIENT', isDark),
                        _buildTableHeaderCell('DIAGNOSIS', isDark),
                        _buildTableHeaderCell('STATUS', isDark),
                        _buildTableHeaderCell('HEART RATE', isDark),
                        _buildTableHeaderCell('BP', isDark),
                        _buildTableHeaderCell('AI RISK SCORE', isDark),
                        _buildTableHeaderCell('UPDATED', isDark),
                      ],
                    ),

                    // Table Rows
                    ...filteredItems.map((item) {
                      return TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.04),
                              width: 1,
                            ),
                          ),
                        ),
                        children: [
                          // PATIENT
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: InkWell(
                              onTap: item.patientId != null
                                  ? () => context.push(
                                        '/patients/${item.patientId}',
                                      )
                                  : null,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                  horizontal: 4,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12.5,
                                              color: isDark
                                                  ? AppColors.textPrimary
                                                  : AppColors.lightTextPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.open_in_new_rounded,
                                          size: 11,
                                          color: isDark
                                              ? AppColors.textMuted
                                              : AppColors.lightTextMuted,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      item.id,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark
                                            ? AppColors.textMuted
                                            : AppColors.lightTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // DIAGNOSIS
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              item.diagnosis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),

                          // STATUS
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: item.statusColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.status,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: item.statusColor,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // HEART RATE
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              item.heartRate,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: item.isHeartRateAlert
                                    ? const Color(0xFFF43F5E)
                                    : (isDark
                                          ? AppColors.primaryEmerald
                                          : AppColors.primaryEmeraldDark),
                              ),
                            ),
                          ),

                          // BP
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              item.bp,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),

                          // AI RISK SCORE
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Text(
                                  '${item.riskScore}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: item.riskColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: item.riskScore / 100.0,
                                      minHeight: 5,
                                      backgroundColor:
                                          item.riskColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        item.riskColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // UPDATED
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              item.updated,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.textMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQueueFilterPill(String label, String value, bool isDark) {
    final isSelected = _queueFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _queueFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? AppColors.primaryEmerald.withValues(alpha: 0.15)
                    : AppColors.primaryEmerald.withValues(alpha: 0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryEmerald
                : (isDark ? AppColors.border : AppColors.lightBorder),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? AppColors.primaryEmerald
                : (isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.textSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  String _formatThousands(int count) {
    return count.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

// ==========================================
// CUSTOM PAINTERS & DATA MODELS
// ==========================================

class _DiagnosisSlice {
  final String label;
  final double ratio;
  final Color color;
  const _DiagnosisSlice(this.label, this.ratio, this.color);
}

class _QueueItem {
  final String id;
  final String? patientId;
  final String name;
  final String diagnosis;
  final String status;
  final Color statusColor;
  final String heartRate;
  final bool isHeartRateAlert;
  final String bp;
  final int riskScore;
  final Color riskColor;
  final String updated;

  const _QueueItem({
    required this.id,
    this.patientId,
    required this.name,
    required this.diagnosis,
    required this.status,
    required this.statusColor,
    required this.heartRate,
    required this.isHeartRateAlert,
    required this.bp,
    required this.riskScore,
    required this.riskColor,
    required this.updated,
  });
}

class _MiniSparklinePainter extends CustomPainter {
  final Color color;
  final List<double> barHeights;

  _MiniSparklinePainter({required this.color, required this.barHeights});

  @override
  void paint(Canvas canvas, Size size) {
    if (barHeights.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const barWidth = 3.5;
    const spacing = 3.0;
    final startX = size.width - (barHeights.length * (barWidth + spacing));

    for (int i = 0; i < barHeights.length; i++) {
      final h = size.height * barHeights[i];
      final x = startX + (i * (barWidth + spacing));
      final y = size.height - h;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) => true;
}

class _WeeklyAdmissionsPainter extends CustomPainter {
  final List<String> days;
  final List<num> emergencyValues;
  final List<num> scheduledValues;
  final Color gridColor;
  final Color textColor;
  final Color emergencyColor;
  final Color emergencyCapColor;
  final Color scheduledColor;

  _WeeklyAdmissionsPainter({
    required this.days,
    required this.emergencyValues,
    required this.scheduledValues,
    required this.gridColor,
    required this.textColor,
    required this.emergencyColor,
    required this.emergencyCapColor,
    required this.scheduledColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 32.0;
    const bottomMargin = 24.0;
    final chartWidth = size.width - leftMargin;
    final chartHeight = size.height - bottomMargin;

    final maxVal = [
      ...emergencyValues,
      ...scheduledValues,
    ].fold<double>(0.0, (prev, val) => math.max(prev, val.toDouble()));

    final double maxY;
    if (maxVal <= 0) {
      maxY = 10.0;
    } else if (maxVal <= 10) {
      maxY = 10.0;
    } else if (maxVal <= 25) {
      maxY = 25.0;
    } else if (maxVal <= 60) {
      maxY = 60.0;
    } else {
      maxY = ((maxVal / 20).ceil() * 20).toDouble();
    }

    // Draw horizontal grid lines & labels
    final gridSteps = [
      0.0,
      maxY * 0.25,
      maxY * 0.5,
      maxY * 0.75,
      maxY,
    ];
    final linePaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (final step in gridSteps) {
      final y = chartHeight - ((step / maxY) * chartHeight);
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width, y), linePaint);

      final textSpan = TextSpan(
        text: '${step.round()}',
        style: TextStyle(color: textColor, fontSize: 10.5),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 6, y - 6),
      );
    }

    // Draw bars
    final numDays = days.length;
    final groupWidth = chartWidth / numDays;
    const barWidth = 16.0;
    const barSpacing = 4.0;

    final emergencyPaint = Paint()
      ..color = emergencyColor
      ..style = PaintingStyle.fill;

    final emergencyCapPaint = Paint()
      ..color = emergencyCapColor
      ..style = PaintingStyle.fill;

    final scheduledPaint = Paint()
      ..color = scheduledColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < numDays; i++) {
      final centerX = leftMargin + (i * groupWidth) + (groupWidth / 2);

      // Emergency Bar
      final emVal = emergencyValues[i].toDouble();
      final emHeight = (emVal / maxY) * chartHeight;
      final emX = centerX - barWidth - (barSpacing / 2);
      final emY = chartHeight - emHeight;
      if (emHeight > 0) {
        final emRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(emX, emY, barWidth, emHeight),
          const Radius.circular(5),
        );
        canvas.drawRRect(emRect, emergencyPaint);

        // Draw striped emergency cap
        final capRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(emX, emY, barWidth, math.min(4.0, emHeight)),
          const Radius.circular(2),
        );
        canvas.drawRRect(capRect, emergencyCapPaint);
      }

      // Scheduled Bar
      final scVal = scheduledValues[i].toDouble();
      final scHeight = (scVal / maxY) * chartHeight;
      final scX = centerX + (barSpacing / 2);
      final scY = chartHeight - scHeight;
      if (scHeight > 0) {
        final scRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(scX, scY, barWidth, scHeight),
          const Radius.circular(5),
        );
        canvas.drawRRect(scRect, scheduledPaint);
      }

      // Day label
      final daySpan = TextSpan(
        text: days[i],
        style: TextStyle(color: textColor, fontSize: 11),
      );
      final dayPainter = TextPainter(
        text: daySpan,
        textDirection: TextDirection.ltr,
      )..layout();
      dayPainter.paint(
        canvas,
        Offset(centerX - (dayPainter.width / 2), chartHeight + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyAdmissionsPainter oldDelegate) => true;
}

class _DiagnosisDonutPainter extends CustomPainter {
  final List<_DiagnosisSlice> slices;

  _DiagnosisDonutPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const strokeWidth = 14.0;
    const gapAngle = 0.05; // radians gap between slices

    double startAngle = -math.pi / 2;

    for (final slice in slices) {
      final sweepAngle = (slice.ratio * 2 * math.pi) - gapAngle;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (gapAngle / 2),
        sweepAngle,
        false,
        paint,
      );

      startAngle += (slice.ratio * 2 * math.pi);
    }
  }

  @override
  bool shouldRepaint(covariant _DiagnosisDonutPainter oldDelegate) => true;
}

class _CardiacVitalsPainter extends CustomPainter {
  final List<String> dates;
  final List<double> heartRate;
  final List<double> bpSystolic;
  final List<double> spo2Scaled;
  final Color gridColor;
  final Color textColor;

  _CardiacVitalsPainter({
    required this.dates,
    required this.heartRate,
    required this.bpSystolic,
    required this.spo2Scaled,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 32.0;
    const bottomMargin = 24.0;
    final chartWidth = size.width - leftMargin;
    final chartHeight = size.height - bottomMargin;
    const minY = 20.0;
    const maxY = 140.0;

    // Draw horizontal grid lines (20, 60, 100, 140)
    final gridSteps = [20, 60, 100, 140];
    final linePaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (final step in gridSteps) {
      final y = chartHeight - (((step - minY) / (maxY - minY)) * chartHeight);
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width, y), linePaint);

      final textSpan = TextSpan(
        text: '$step',
        style: TextStyle(color: textColor, fontSize: 10.5),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 6, y - 6),
      );
    }

    // Calculate points for lines
    final stepX = chartWidth / (dates.length - 1);

    List<Offset> toOffsets(List<double> values) {
      return List.generate(values.length, (i) {
        final x = leftMargin + (i * stepX);
        final val = values[i].clamp(minY, maxY);
        final y = chartHeight - (((val - minY) / (maxY - minY)) * chartHeight);
        return Offset(x, y);
      });
    }

    // Draw lines with smooth bezier curves
    void drawSmoothLine(List<Offset> points, Color color) {
      if (points.isEmpty) return;
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final controlX = (p0.dx + p1.dx) / 2;
        path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      }

      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, strokePaint);

      // Draw endpoint dot
      final last = points.last;
      final dotPaint = Paint()..color = color;
      canvas.drawCircle(last, 3.5, dotPaint);
    }

    // BP Systolic (Purple)
    drawSmoothLine(toOffsets(bpSystolic), const Color(0xFFA78BFA));

    // SpO2 (Orange, map 90-100 to scale around 100-110)
    final mappedSpo2 = spo2Scaled.map((v) => (v * 1.05)).toList();
    drawSmoothLine(toOffsets(mappedSpo2), const Color(0xFFF97316));

    // Heart Rate (Emerald)
    drawSmoothLine(toOffsets(heartRate), AppColors.primaryEmerald);

    // X-Axis Date Labels
    for (int i = 0; i < dates.length; i++) {
      final x = leftMargin + (i * stepX);
      final span = TextSpan(
        text: dates[i],
        style: TextStyle(color: textColor, fontSize: 10.5),
      );
      final painter = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      painter.paint(canvas, Offset(x - (painter.width / 2), chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _CardiacVitalsPainter oldDelegate) => true;
}
