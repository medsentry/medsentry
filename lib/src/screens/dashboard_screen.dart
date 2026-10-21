import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/context_extensions.dart';
import '../widgets/app_card.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/medsentry_command_dialog.dart';
import '../widgets/screen_kit.dart';

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
    final isDesktop = context.isDesktop;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),

          // Quick clinical actions, the screen's most frequent jobs
          _buildQuickActionStrip(context, isDark),
          const SizedBox(height: 16),

          // TIER 1: headline figures
          _buildKpiCardsRow(context),
          const SizedBox(height: 16),

          // TIER 2: Dual Charts (Weekly Admissions + Diagnosis Mix)
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: _buildWeeklyAdmissionsCard(context)),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: _buildDiagnosisMixCard(context)),
              ],
            )
          else ...[
            _buildWeeklyAdmissionsCard(context),
            const SizedBox(height: 16),
            _buildDiagnosisMixCard(context),
          ],
          const SizedBox(height: 16),

          // TIER 3: Trends & Priority Patient Queue
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildCardiacVitalsCard(context)),
                const SizedBox(width: 16),
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
          const SizedBox(height: 16),

          // TIER 4: Epidemiological Disease Surveillance & Morbidity Radar (DOH FHSIS)
          _buildEpidemiologicalSurveillanceCard(context),
        ],
      ),
    );
  }

  // ==========================================
  // QUICK ACTIONS STRIP
  // ==========================================
  Widget _buildQuickActionStrip(BuildContext context, bool isDark) {
    final user = ref.watch(currentUserProvider);
    final settings = ref.watch(systemSettingsProvider).valueOrNull;
    final canAccessPatients =
        user?.permissions.canAccessPatientRecords ?? false;
    final canRegister = user?.permissions.canRegisterPatients ?? false;
    final canGenerateCerts =
        (user?.permissions.canGenerateCertificates ?? false) &&
        (settings?.enableCertificates ?? true);
    final canManageDocs = user?.permissions.canManageDocuments ?? false;
    final canViewReports =
        (user?.permissions.canViewReports ?? false) &&
        (settings?.enableReports ?? true);
    final canViewAudit =
        (user?.permissions.canViewAuditLogs ?? false) &&
        (settings?.enableAuditLogs ?? true);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (canAccessPatients && canRegister) ...[
            _buildQuickActionPill(
              context,
              icon: Icons.person_add_outlined,
              label: 'Register Patient',
              isPrimary: true,
              onTap: () => context.go('/patients?action=add-patient'),
            ),
            const SizedBox(width: 8),
          ],
          if (canAccessPatients && canGenerateCerts) ...[
            _buildQuickActionPill(
              context,
              icon: Icons.edit_document,
              label: 'Issue Certificate',
              onTap: () => context.go('/certificates'),
            ),
            const SizedBox(width: 8),
          ],
          if (canAccessPatients && canManageDocs) ...[
            _buildQuickActionPill(
              context,
              icon: Icons.upload_file_outlined,
              label: 'Upload Document',
              onTap: () => context.go('/documents'),
            ),
            const SizedBox(width: 8),
          ],
          if (user?.isSuperAdmin == true) ...[
            _buildQuickActionPill(
              context,
              icon: Icons.domain_rounded,
              label: 'Manage RHU Units',
              onTap: () => context.go('/rhus'),
            ),
            const SizedBox(width: 8),
            _buildQuickActionPill(
              context,
              icon: Icons.badge_outlined,
              label: 'Staff Accounts',
              onTap: () => context.go('/staff'),
            ),
            const SizedBox(width: 8),
          ],
          _buildQuickActionPill(
            context,
            icon: Icons.sync_rounded,
            label: 'Cloud Sync',
            onTap: () async {
              try {
                final result = await ref.read(syncServiceProvider).startSync();
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(result.message)));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
                }
              }
            },
          ),
          const SizedBox(width: 8),
          _buildQuickActionPill(
            context,
            icon: Icons.keyboard_command_key_rounded,
            label: 'Command Palette',
            onTap: () => showMedsentryCommandPalette(context, ref),
          ),
          if (canViewReports) ...[
            const SizedBox(width: 8),
            _buildQuickActionPill(
              context,
              icon: Icons.bar_chart_rounded,
              label: 'FHSIS & DOH Reports',
              onTap: () => context.go('/reports'),
            ),
          ] else if (canViewAudit) ...[
            const SizedBox(width: 8),
            _buildQuickActionPill(
              context,
              icon: Icons.history_edu_outlined,
              label: 'Audit Trail',
              onTap: () => context.go('/audit-logs'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryEmerald = AppColors.accent(isDark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: isPrimary
                ? (isDark
                      ? primaryEmerald.withValues(alpha: 0.15)
                      : primaryEmerald.withValues(alpha: 0.08))
                : (isDark ? AppColors.cardSurface : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPrimary
                  ? primaryEmerald.withValues(alpha: 0.35)
                  : (isDark ? AppColors.borderSubtle : AppColors.lightBorder),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isPrimary
                    ? primaryEmerald
                    : (isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                  color: isPrimary
                      ? (isDark ? primaryEmerald : AppColors.primaryEmeraldDark)
                      : (isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // EPIDEMIOLOGICAL SURVEILLANCE & CATCHMENT DISTRIBUTION
  // ==========================================
  Widget _buildEpidemiologicalSurveillanceCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allPatients = ref.watch(patientsProvider).valueOrNull ?? [];
    final settings = ref.watch(systemSettingsProvider).valueOrNull;
    final user = ref.watch(currentUserProvider);
    final clinics = ref.watch(clinicsProvider).valueOrNull ?? [];
    final activeClinicId = ref.watch(activeClinicIdProvider);

    String catchmentName = settings?.organizationName ?? 'RHU Catchment Area';
    if (activeClinicId != null) {
      final matched = clinics.where((c) => c.id == activeClinicId).firstOrNull;
      if (matched != null) {
        catchmentName = '${matched.name} Catchment';
      }
    }

    // Compute live Barangay & Clinical Category distribution from real patients
    final barangayCounts = <String, int>{};
    for (final p in allPatients) {
      final brgy = (p.barangay != null && p.barangay!.trim().isNotEmpty)
          ? p.barangay!.trim()
          : 'Unassigned Barangay';
      barangayCounts[brgy] = (barangayCounts[brgy] ?? 0) + 1;
    }

    final sortedEntries = barangayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalCount = math.max(1, allPatients.length);
    final surveillanceData = sortedEntries.take(6).map((e) {
      final ratio = (e.value / totalCount).clamp(0.0, 1.0);
      final String statusLabel;
      final Color densityColor;

      if (ratio >= 0.35) {
        statusLabel = 'High Volume Cluster';
        densityColor =
            AppColors.primaryEmeraldDark; // Primary deep emerald/teal
      } else if (ratio >= 0.15) {
        statusLabel = 'Active Catchment';
        densityColor = AppColors.primaryEmerald; // Mid teal
      } else {
        statusLabel = 'Monitored Baseline';
        densityColor = isDark
            ? AppColors.neutral
            : AppColors.lightTextMuted; // Slate neutral
      }

      return (
        'Barangay ${e.key}',
        '${e.value} ${e.value == 1 ? 'patient' : 'patients'}',
        ratio,
        statusLabel,
        densityColor,
        Icons.location_on_outlined,
      );
    }).toList();

    final canViewReports =
        (user?.permissions.canViewReports ?? false) &&
        (settings?.enableReports ?? true);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.radar_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Catchment Barangay & Population Surveillance',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time barangay distribution from registered patient records ($catchmentName)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (canViewReports && !ResponsiveLayout.isMobile(context))
                OutlinedButton.icon(
                  onPressed: () => context.go('/reports'),
                  icon: const Icon(Icons.assessment_outlined, size: 14),
                  label: const Text(
                    'Export FHSIS Report',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
          // On phones the button gets its own line instead of squeezing the
          // heading off-screen.
          if (canViewReports && ResponsiveLayout.isMobile(context)) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.go('/reports'),
              icon: const Icon(Icons.assessment_outlined, size: 14),
              label: const Text(
                'Export FHSIS Report',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (surveillanceData.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No patient catchment records registered yet. Add patients to view live barangay distribution.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textMuted
                      : AppColors.lightTextMuted,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: surveillanceData.map((item) {
                    final width = isWide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.inputSurface
                              : Colors.grey.shade50,
                          borderRadius: AppRadius.roundedMd,
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderSubtle
                                : AppColors.lightBorderSubtle,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 15,
                                  color: isDark
                                      ? AppColors.textTertiary
                                      : AppColors.lightTextSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.$1,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.$2,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: item.$3,
                              backgroundColor: isDark
                                  ? AppColors.borderSubtle
                                  : AppColors.lightBorder,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                item.$5,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 6,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$catchmentName · ${(item.$3 * 100).toStringAsFixed(0)}% of cohort',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                      color: isDark
                                          ? AppColors.textMuted
                                          : AppColors.lightTextMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.$5.withValues(alpha: 0.1),
                                    borderRadius: AppRadius.roundedSm,
                                  ),
                                  child: Text(
                                    item.$4,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: item.$5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // TITLE ROW
  // ==========================================
  Widget _buildHeader(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final settings = ref.watch(systemSettingsProvider).valueOrNull;
    final clinics = ref.watch(clinicsProvider).valueOrNull;
    final activeClinicId = ref.watch(activeClinicIdProvider);
    final t = ScreenTokens.of(context);

    String scope;
    if (user?.isSuperAdmin == true) {
      scope = clinics == null
          ? 'Provincial health network'
          : 'Provincial health network, ${clinics.length} RHU '
                '${clinics.length == 1 ? 'facility' : 'facilities'} connected';
    } else {
      final clinic = clinics?.where((c) => c.id == activeClinicId).firstOrNull;
      scope = clinic?.name ?? settings?.organizationName ?? 'Rural Health Unit';
    }

    return ScreenHeader(
      icon: Icons.space_dashboard_outlined,
      title: 'Dashboard',
      subtitle:
          '$scope. Updated ${DateFormat('MMM d, h:mm a').format(DateTime.now())}',
      actions: [
        if (user?.isSuperAdmin == true)
          OutlinedButton.icon(
            style: t.outlinedButton,
            onPressed: () => context.go('/rhus'),
            icon: const Icon(Icons.domain_rounded, size: 16),
            label: const Text('Manage RHUs'),
          ),
      ],
    );
  }

  // ==========================================
  // TIER 1: HEADLINE FIGURES (one divided strip)
  // ==========================================
  Widget _buildKpiCardsRow(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final extendedStatsAsync = ref.watch(extendedDashboardStatsProvider);
    final allPatients = ref.watch(patientsProvider).valueOrNull ?? [];
    final allDocuments = ref.watch(documentsProvider).valueOrNull ?? [];
    final allCertificates =
        ref.watch(issuedCertificatesProvider).valueOrNull ?? [];

    final totalPatients =
        statsAsync.valueOrNull?.totalPatients ?? allPatients.length;
    final todayPatients = statsAsync.valueOrNull?.todayPatients ?? 0;

    final totalDocs = allDocuments.length;
    final docsToday = extendedStatsAsync.valueOrNull?.documentsToday ?? 0;

    final totalCerts = allCertificates.length;
    final now = DateTime.now();
    final certsToday = allCertificates
        .where(
          (c) =>
              c.issuedAt.year == now.year &&
              c.issuedAt.month == now.month &&
              c.issuedAt.day == now.day,
        )
        .length;

    final alertsCount =
        extendedStatsAsync.valueOrNull?.unreadNotifications ?? 0;
    final riskCount = allPatients
        .where(
          (p) =>
              p.isPwd ||
              p.category == PatientCategory.senior ||
              p.category == PatientCategory.seniorCitizen ||
              (p.allergies != null && p.allergies!.isNotEmpty),
        )
        .length;

    final canAccessPatients =
        user?.permissions.canAccessPatientRecords ?? false;
    final canManageDocs = user?.permissions.canManageDocuments ?? false;
    final canGenerateCerts = user?.permissions.canGenerateCertificates ?? false;

    String today(int n, String noun) =>
        n > 0 ? '+$n $noun today' : 'None $noun today';

    return MetricStrip(
      metrics: [
        Metric(
          label: 'Active patients',
          value: _formatThousands(totalPatients),
          note: today(todayPatients, 'registered'),
          onTap: () => context.go(canAccessPatients ? '/patients' : '/rhus'),
        ),
        Metric(
          label: 'Medical documents',
          value: _formatThousands(totalDocs),
          note: today(docsToday, 'uploaded'),
          onTap: () => context.go(canManageDocs ? '/documents' : '/audit-logs'),
        ),
        Metric(
          label: 'Certificates issued',
          value: _formatThousands(totalCerts),
          note: today(certsToday, 'issued'),
          onTap: () =>
              context.go(canGenerateCerts ? '/certificates' : '/staff'),
        ),
        Metric(
          label: 'Priority patients',
          value: _formatThousands(riskCount),
          note: alertsCount > 0
              ? '$alertsCount unread clinical ${alertsCount == 1 ? 'alert' : 'alerts'}'
              : 'Seniors, PWD and known allergies',
          noteIsAlert: alertsCount > 0,
          onTap: () =>
              context.go(canAccessPatients ? '/patients' : '/audit-logs'),
        ),
      ],
    );
  }

  // ==========================================
  // TIER 2: WEEKLY ADMISSIONS DUAL-BAR CHART
  // ==========================================
  Widget _buildWeeklyAdmissionsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allPatients = ref.watch(patientsProvider).valueOrNull ?? [];

    // Patients registered this week (Mon-Fri), split by the same "priority"
    // rule as the Priority patients card. The app records registrations, not
    // admissions or emergencies, so the chart reports exactly that.
    final days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final priorityCounts = [0, 0, 0, 0, 0];
    final otherCounts = [0, 0, 0, 0, 0];
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    for (final p in allPatients) {
      final created = p.createdAt?.toLocal();
      if (created == null ||
          created.isBefore(weekStart) ||
          !created.isBefore(weekEnd)) {
        continue;
      }
      final weekday = created.weekday;
      if (weekday >= 1 && weekday <= 5) {
        final idx = weekday - 1;
        final isPriority =
            p.isPwd ||
            p.category == PatientCategory.senior ||
            p.category == PatientCategory.seniorCitizen ||
            (p.allergies?.isNotEmpty == true);
        if (isPriority) {
          priorityCounts[idx]++;
        } else {
          otherCounts[idx]++;
        }
      }
    }
    final emergencyCounts = priorityCounts;
    final scheduledCounts = otherCounts;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Registrations This Week',
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
                      'Priority (senior, PWD, allergy) vs other patients',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                    : AppColors.lightBorder,
                emergencyCapColor: isDark
                    ? const Color(0xFFE5E7EB)
                    : AppColors.lightTextSecondary,
                scheduledColor: AppColors.primaryEmeraldDark,
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
                label: 'Priority',
                isDark: isDark,
              ),
              const SizedBox(width: 24),
              _buildLegendItem(
                color: AppColors.primaryEmeraldDark,
                label: 'Other',
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

    final daysWindow = _diagnosisTimeframe == 'Last 7 days'
        ? 7
        : (_diagnosisTimeframe == 'Last 90 days' ? 90 : 30);
    final cutoff = DateTime.now().subtract(Duration(days: daysWindow));

    final windowedPatients = allPatients.where((p) {
      final dt = p.updatedAt ?? p.createdAt;
      return dt == null || !dt.isBefore(cutoff);
    }).toList();

    // Only the selected period. Falling back to all patients when the period
    // was empty showed all-time figures under a "Last 7 days" label.
    final cohort = windowedPatients;

    int cardiovascular = 0;
    int hypertension = 0;
    int diabetes = 0;
    int respiratory = 0;
    int general = 0;

    // Whole words only: substring matching counted any word containing "bp"
    // or "resp" (e.g. "responds") as a condition.
    bool mentions(String text, String pattern) =>
        RegExp('\\b(?:$pattern)\\b').hasMatch(text);

    for (final p in cohort) {
      final med = (p.medicalHistory ?? '').toLowerCase();
      if (mentions(med, r'hypertensi\w*|htn|bp|high blood pressure')) {
        hypertension++;
      } else if (mentions(med, r'heart|arrhythmi\w*|cardi\w*|chf')) {
        cardiovascular++;
      } else if (mentions(med, r'diabet\w*|dm|glucose|high blood sugar')) {
        diabetes++;
      } else if (mentions(
        med,
        r'respirator\w*|asthma|copd|cough|pneumonia|tuberculosis|tb|ptb',
      )) {
        respiratory++;
      } else {
        general++;
      }
    }

    final total = cohort.length;
    final rawSlices = <_DiagnosisSlice>[
      if (cardiovascular > 0)
        _DiagnosisSlice(
          'Cardiovascular',
          cardiovascular / total,
          AppColors.primaryEmeraldDark,
        ),
      if (hypertension > 0)
        _DiagnosisSlice(
          'Hypertension',
          hypertension / total,
          AppColors.primaryEmerald,
        ),
      if (diabetes > 0)
        _DiagnosisSlice('Diabetes', diabetes / total, const Color(0xFF6EE7B7)),
      if (respiratory > 0)
        _DiagnosisSlice(
          'Respiratory',
          respiratory / total,
          const Color(0xFFA7F3D0),
        ),
      if (general > 0)
        _DiagnosisSlice('General Care', general / total, AppColors.neutral),
    ];

    final slices = rawSlices.isEmpty
        ? const [
            _DiagnosisSlice('No records in period', 1.0, AppColors.neutral),
          ]
        : rawSlices;

    final chronicCount = cardiovascular + hypertension + diabetes + respiratory;
    final barangaySet = cohort
        .map((p) => p.barangay?.trim() ?? '')
        .where((b) => b.isNotEmpty)
        .toSet();
    final insightSummary = allPatients.isEmpty
        ? 'No patient records registered yet. Register patients with medical history to populate live cohort analytics.'
        : cohort.isEmpty
        ? 'No patient records were added or updated in the ${_diagnosisTimeframe.toLowerCase()}.'
        : 'Out of ${cohort.length} active patients in this cohort, $chronicCount have recorded chronic or respiratory conditions across ${math.max(1, barangaySet.length)} ${barangaySet.length == 1 ? 'barangay' : 'barangays'}.';

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clinical Condition Mix',
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
                      'Active patient medical history',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

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
                  borderRadius: BorderRadius.circular(8),
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
                      fontFamily: AppType.family,
                      fontSize: 13,
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
          const SizedBox(height: 16),

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
                          _formatThousands(cohort.length),
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
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(s.ratio * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12,
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
              color: isDark
                  ? AppColors.inputSurface
                  : AppColors.lightElevatedSurface,
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
                  Icons.insights_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insightSummary,
                    style: TextStyle(
                      fontSize: 12,
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
  // TIER 3: RHU CLINICAL & DOCUMENT ACTIVITY TREND
  // ==========================================
  Widget _buildCardiacVitalsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allPatients = ref.watch(patientsProvider).valueOrNull ?? [];
    final allDocuments = ref.watch(documentsProvider).valueOrNull ?? [];
    final allCertificates =
        ref.watch(issuedCertificatesProvider).valueOrNull ?? [];

    final intervalDays = _vitalsTimeframe == '7D'
        ? 1
        : (_vitalsTimeframe == '90D' ? 15 : 5);
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final dates = <String>[];
    final patientSeries = <double>[];
    final docSeries = <double>[];
    final certSeries = <double>[];

    for (int i = 0; i < 6; i++) {
      final bucketEnd = todayEnd.subtract(
        Duration(days: (5 - i) * intervalDays),
      );
      final bucketStart = bucketEnd.subtract(Duration(days: intervalDays));
      dates.add(DateFormat('MMM d').format(bucketEnd));

      final pCount = allPatients.where((p) {
        final dt = p.createdAt ?? p.updatedAt;
        return dt != null &&
            !dt.isBefore(bucketStart) &&
            !dt.isAfter(bucketEnd);
      }).length;

      final dCount = allDocuments.where((d) {
        final dt = d.createdAt;
        return dt != null &&
            !dt.isBefore(bucketStart) &&
            !dt.isAfter(bucketEnd);
      }).length;

      final cCount = allCertificates.where((c) {
        final dt = c.issuedAt;
        return !dt.isBefore(bucketStart) && !dt.isAfter(bucketEnd);
      }).length;

      patientSeries.add(pCount.toDouble());
      docSeries.add(dCount.toDouble());
      certSeries.add(cCount.toDouble());
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 520;
              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RHU Records Activity — $_vitalsTimeframe Trend',
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
                    'Registrations, uploaded documents & issued certificates',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              );

              final pillsSection = Row(
                mainAxisSize: MainAxisSize.min,
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
                                  : AppColors.primaryEmeraldDeep.withValues(
                                      alpha: 0.10,
                                    ))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? (isDark
                                    ? AppColors.borderActive
                                    : AppColors.primaryEmeraldDeep)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        tf,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? (isDark
                                    ? AppColors.textPrimary
                                    : AppColors.primaryEmeraldDeep)
                              : (isDark
                                    ? AppColors.textMuted
                                    : AppColors.lightTextMuted),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );

              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 10),
                    pillsSection,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleSection),
                  pillsSection,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Multi-line chart
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _ActivityTrendPainter(
                dates: dates,
                patientSeries: patientSeries,
                documentSeries: docSeries,
                certificateSeries: certSeries,
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
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              _buildLegendItem(
                color: AppColors.primaryEmeraldDark,
                label: 'Patients',
                isDark: isDark,
              ),
              _buildLegendItem(
                color: AppColors.neutral,
                label: 'Documents',
                isDark: isDark,
              ),
              _buildLegendItem(
                color: const Color(0xFF6EE7B7),
                label: 'Certificates',
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TIER 3: PRIORITY PATIENT REGISTRY
  // ==========================================
  Widget _buildPriorityPatientQueueCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final canAccessPatients =
        user?.permissions.canAccessPatientRecords ?? false;
    final allPatients = ref.watch(patientsProvider).valueOrNull ?? [];
    final allDocuments = ref.watch(documentsProvider).valueOrNull ?? [];

    final docCountByPatient = <String, int>{};
    for (final d in allDocuments) {
      docCountByPatient[d.patientId] =
          (docCountByPatient[d.patientId] ?? 0) + 1;
    }

    final allQueueItems =
        allPatients.map((p) {
          final isCritical =
              p.isPwd ||
              (p.allergies?.isNotEmpty == true &&
                  p.medicalHistory?.isNotEmpty == true);
          final isMonitored =
              p.category == PatientCategory.senior ||
              p.category == PatientCategory.seniorCitizen ||
              p.allergies?.isNotEmpty == true ||
              p.medicalHistory?.isNotEmpty == true;

          final String status;
          final Color statusColor;
          final int priorityWeight;

          if (isCritical) {
            status = 'Critical';
            statusColor = isDark
                ? const Color(0xFFF43F5E)
                : const Color(0xFFBE123C);
            priorityWeight = 3;
          } else if (isMonitored) {
            status = 'Monitored';
            statusColor = isDark
                ? const Color(0xFFF59E0B)
                : const Color(0xFFB45309);
            priorityWeight = 2;
          } else {
            status = 'Active';
            statusColor = AppColors.accent(
              Theme.of(context).brightness == Brightness.dark,
            );
            priorityWeight = 1;
          }

          final shortId =
              '#P-${p.id.length >= 5 ? p.id.substring(p.id.length - 5).toUpperCase() : p.id}';
          final clinicalAlert = p.medicalHistory?.isNotEmpty == true
              ? p.medicalHistory!
              : (p.allergies?.isNotEmpty == true
                    ? 'Allergy: ${p.allergies}'
                    : (p.category?.displayName ?? 'General Care'));

          final barangay = (p.barangay != null && p.barangay!.trim().isNotEmpty)
              ? p.barangay!.trim()
              : 'Unassigned';
          final philhealth =
              (p.philhealthNumber != null &&
                  p.philhealthNumber!.trim().isNotEmpty)
              ? p.philhealthNumber!.trim()
              : 'None on file';
          final docCount = docCountByPatient[p.id] ?? 0;

          final updatedAt = p.updatedAt ?? p.createdAt ?? DateTime.now();
          final updatedDiff = DateTime.now().difference(updatedAt);
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
            diagnosis: clinicalAlert,
            status: status,
            statusColor: statusColor,
            barangay: barangay,
            philhealth: philhealth,
            documentCount: docCount,
            priorityWeight: priorityWeight,
            updatedAt: updatedAt,
            updated: updatedStr,
          );
        }).toList()..sort((a, b) {
          final cmp = b.priorityWeight.compareTo(a.priorityWeight);
          if (cmp != 0) return cmp;
          return b.updatedAt.compareTo(a.updatedAt);
        });

    final filteredItems = allQueueItems.where((item) {
      if (_queueFilter == 'all') return true;
      if (_queueFilter == 'critical') {
        return item.status.toLowerCase() == 'critical';
      }
      if (_queueFilter == 'improving') {
        return item.status.toLowerCase() == 'monitored' ||
            item.status.toLowerCase() == 'active';
      }
      return true;
    }).toList();

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 520;
              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Priority Patient Registry',
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
                    'Sorted by clinical priority · ${filteredItems.length} patients',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              );

              final pillsSection = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQueueFilterPill('All', 'all', isDark),
                  const SizedBox(width: 6),
                  _buildQueueFilterPill('Priority', 'critical', isDark),
                  const SizedBox(width: 6),
                  _buildQueueFilterPill('Monitored', 'improving', isDark),
                ],
              );

              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 10),
                    pillsSection,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleSection),
                  pillsSection,
                ],
              );
            },
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
                          ? 'No registered patients in registry'
                          : 'No patients matching selected filter',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      allPatients.isEmpty
                          ? 'Register a patient to view real-time clinical status and documents.'
                          : 'Try selecting a different filter pill above.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    if (allPatients.isEmpty && canAccessPatients) ...[
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
                constraints: const BoxConstraints(minWidth: 540),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.2), // PATIENT
                    1: FlexColumnWidth(2.1), // CLINICAL ALERTS / CATEGORY
                    2: FlexColumnWidth(1.3), // STATUS
                    3: FlexColumnWidth(1.4), // BARANGAY
                    4: FlexColumnWidth(1.5), // PHILHEALTH
                    5: FlexColumnWidth(1.2), // DOCUMENTS
                    6: FlexColumnWidth(1.3), // UPDATED
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    // Table Header, ruled off in the ledger's margin red
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.ledgerRule(isDark),
                            width: 1.5,
                          ),
                        ),
                      ),
                      children: [
                        _buildTableHeaderCell('Patient', isDark),
                        _buildTableHeaderCell('Clinical alerts', isDark),
                        _buildTableHeaderCell('Status', isDark),
                        _buildTableHeaderCell('Barangay', isDark),
                        _buildTableHeaderCell('PhilHealth', isDark),
                        _buildTableHeaderCell('Documents', isDark),
                        _buildTableHeaderCell('Updated', isDark),
                      ],
                    ),

                    // Table Rows
                    ...filteredItems.take(10).map((item) {
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
                              onTap:
                                  (canAccessPatients && item.patientId != null)
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
                                              fontSize: 14,
                                              color: isDark
                                                  ? AppColors.textPrimary
                                                  : AppColors.lightTextPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (canAccessPatients) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.open_in_new_rounded,
                                            size: 11,
                                            color: isDark
                                                ? AppColors.textMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      item.id,
                                      style: TextStyle(
                                        fontSize: 12,
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

                          // CLINICAL / ALERTS
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              item.diagnosis,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
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
                                  color: item.statusColor.withValues(
                                    alpha: isDark ? 0.14 : 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: item.statusColor,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // BARANGAY
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              item.barangay,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.textPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),

                          // PHILHEALTH
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              item.philhealth,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),

                          // DOCUMENTS
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              '${item.documentCount} ${item.documentCount == 1 ? 'file' : 'files'}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: item.documentCount > 0
                                    ? AppColors.accent(isDark)
                                    : (isDark
                                          ? AppColors.textMuted
                                          : AppColors.lightTextMuted),
                              ),
                            ),
                          ),

                          // UPDATED
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              item.updated,
                              style: TextStyle(
                                fontSize: 12,
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
              ? AppColors.accent(isDark).withValues(alpha: isDark ? 0.15 : 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.accent(isDark)
                : (isDark ? AppColors.border : AppColors.lightBorder),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? AppColors.accent(isDark)
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
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark
              ? AppColors.textSecondary
              : AppColors.lightTextSecondary,
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
            fontSize: 13,
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
  final String barangay;
  final String philhealth;
  final int documentCount;
  final int priorityWeight;
  final DateTime updatedAt;
  final String updated;

  const _QueueItem({
    required this.id,
    this.patientId,
    required this.name,
    required this.diagnosis,
    required this.status,
    required this.statusColor,
    required this.barangay,
    required this.philhealth,
    required this.documentCount,
    required this.priorityWeight,
    required this.updatedAt,
    required this.updated,
  });
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
    final gridSteps = [0.0, maxY * 0.25, maxY * 0.5, maxY * 0.75, maxY];
    final linePaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (final step in gridSteps) {
      final y = chartHeight - ((step / maxY) * chartHeight);
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width, y), linePaint);

      final textSpan = TextSpan(
        text: '${step.round()}',
        style: TextStyle(color: textColor, fontSize: 12),
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
        style: TextStyle(color: textColor, fontSize: 12),
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

class _ActivityTrendPainter extends CustomPainter {
  final List<String> dates;
  final List<double> patientSeries;
  final List<double> documentSeries;
  final List<double> certificateSeries;
  final Color gridColor;
  final Color textColor;

  _ActivityTrendPainter({
    required this.dates,
    required this.patientSeries,
    required this.documentSeries,
    required this.certificateSeries,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 32.0;
    const bottomMargin = 24.0;
    final chartWidth = size.width - leftMargin;
    final chartHeight = size.height - bottomMargin;

    final maxVal = [
      ...patientSeries,
      ...documentSeries,
      ...certificateSeries,
    ].fold<double>(0.0, math.max);

    final double maxY = maxVal <= 4
        ? 4.0
        : (maxVal <= 12 ? 12.0 : ((maxVal / 4).ceil() * 4).toDouble());
    const minY = 0.0;

    final gridSteps = [0.0, maxY * 0.25, maxY * 0.5, maxY * 0.75, maxY];
    final linePaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (final step in gridSteps) {
      final y = chartHeight - (((step - minY) / (maxY - minY)) * chartHeight);
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width, y), linePaint);

      final textSpan = TextSpan(
        text: '${step.round()}',
        style: TextStyle(color: textColor, fontSize: 12),
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

    final stepX = dates.length > 1
        ? chartWidth / (dates.length - 1)
        : chartWidth;

    List<Offset> toOffsets(List<double> values) {
      return List.generate(values.length, (i) {
        final x = leftMargin + (i * stepX);
        final val = values[i].clamp(minY, maxY);
        final y = chartHeight - (((val - minY) / (maxY - minY)) * chartHeight);
        return Offset(x, y);
      });
    }

    void drawSmoothLine(List<Offset> points, Color color) {
      if (points.isEmpty) return;
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < points.length - 1; i++) {
        final p1 = points[i + 1];
        path.lineTo(p1.dx, p1.dy);
      }

      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, strokePaint);

      final last = points.last;
      final dotPaint = Paint()..color = color;
      canvas.drawCircle(last, 3.5, dotPaint);
    }

    drawSmoothLine(toOffsets(documentSeries), AppColors.neutral);
    drawSmoothLine(toOffsets(certificateSeries), const Color(0xFF6EE7B7));
    drawSmoothLine(toOffsets(patientSeries), AppColors.primaryEmeraldDark);

    for (int i = 0; i < dates.length; i++) {
      final x = leftMargin + (i * stepX);
      final span = TextSpan(
        text: dates[i],
        style: TextStyle(color: textColor, fontSize: 12),
      );
      final painter = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      painter.paint(canvas, Offset(x - (painter.width / 2), chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityTrendPainter oldDelegate) => true;
}
