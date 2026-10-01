import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/patient.dart';
import '../models/queue.dart';
import '../models/generated_report.dart';
import '../utils/report_date_filter.dart';
import 'providers.dart';

final reportFiltersProvider = StateProvider<ReportFilters>(
  (ref) => ReportFilters.forPreset(ReportDatePreset.thisMonth),
);

/// Report statistics model
class ReportStats {
  final int rangeDays;
  final ReportGrouping grouping;
  final int totalConsultations;
  final int newPatients;
  final int followUps;
  final int avgWaitMinutes;
  final int completedQueueVisits;
  final int documentsInRange;
  final List<DistributionMetric> topDiagnoses;
  final List<ConsultationTrend> consultationTrends;
  final List<ConsultationTrend> newPatientTrends;
  final List<DistributionMetric> patientsByBarangay;
  final List<DistributionMetric> patientsByCategory;
  final MetricDelta consultationsDelta;
  final MetricDelta newPatientsDelta;
  final MetricDelta followUpsDelta;
  final MetricDelta avgWaitDelta;
  final String? peakConsultationLabel;
  final int peakConsultationCount;
  final DateTime timestamp;

  ReportStats({
    required this.rangeDays,
    required this.grouping,
    required this.totalConsultations,
    required this.newPatients,
    required this.followUps,
    required this.avgWaitMinutes,
    required this.completedQueueVisits,
    required this.documentsInRange,
    required this.topDiagnoses,
    required this.consultationTrends,
    required this.newPatientTrends,
    required this.patientsByBarangay,
    required this.patientsByCategory,
    required this.consultationsDelta,
    required this.newPatientsDelta,
    required this.followUpsDelta,
    required this.avgWaitDelta,
    this.peakConsultationLabel,
    this.peakConsultationCount = 0,
    required this.timestamp,
  });

  factory ReportStats.empty() => ReportStats(
    rangeDays: 30,
    grouping: ReportGrouping.day,
    totalConsultations: 0,
    newPatients: 0,
    followUps: 0,
    avgWaitMinutes: 0,
    completedQueueVisits: 0,
    documentsInRange: 0,
    topDiagnoses: [],
    consultationTrends: [],
    newPatientTrends: [],
    patientsByBarangay: [],
    patientsByCategory: [],
    consultationsDelta: MetricDelta.empty(),
    newPatientsDelta: MetricDelta.empty(),
    followUpsDelta: MetricDelta.empty(),
    avgWaitDelta: MetricDelta.empty(),
    timestamp: DateTime.now(),
  );
}

class MetricDelta {
  final double percentChange;
  final bool isPositive;
  final String label;

  const MetricDelta({
    required this.percentChange,
    required this.isPositive,
    required this.label,
  });

  factory MetricDelta.empty() => const MetricDelta(
    percentChange: 0,
    isPositive: true,
    label: 'vs previous period',
  );

  String get formatted {
    if (percentChange.abs() < 0.05) return 'No change';
    final sign = percentChange > 0 ? '+' : '';
    return '$sign${percentChange.toStringAsFixed(1)}%';
  }
}

class DistributionMetric {
  final String label;
  final int value;
  final double percentage;

  DistributionMetric({
    required this.label,
    required this.value,
    required this.percentage,
  });
}

class ConsultationTrend {
  final DateTime date;
  final int count;

  ConsultationTrend({required this.date, required this.count});
}

DateTime _startOfDay(DateTime date) {
  final localDate = date.toLocal();
  return DateTime(localDate.year, localDate.month, localDate.day);
}

bool _isInRange(DateTime? date, DateTime start, DateTime endExclusive) {
  return isWithinReportInterval(date, start, endExclusive);
}

double _percentChange(num current, num previous) {
  if (previous == 0) return current > 0 ? 100.0 : 0.0;
  return ((current - previous) / previous) * 100;
}

MetricDelta _buildDelta({
  required num current,
  required num previous,
  required bool lowerIsBetter,
}) {
  final change = _percentChange(current, previous);
  final improved = lowerIsBetter ? change <= 0 : change >= 0;
  return MetricDelta(
    percentChange: change,
    isPositive: improved,
    label: 'vs previous period',
  );
}

int _waitMinutes(QueueItem item) {
  if (item.startTime != null) {
    return item.startTime!.difference(item.arrivalTime).inMinutes.clamp(0, 480);
  }
  if (item.endTime != null) {
    return item.endTime!.difference(item.arrivalTime).inMinutes.clamp(0, 480);
  }
  return 0;
}

int _averageWaitMinutes(Iterable<QueueItem> items) {
  final waits = items.map(_waitMinutes).where((m) => m > 0).toList();
  if (waits.isEmpty) return 0;
  return waits.reduce((a, b) => a + b) ~/ waits.length;
}

List<ConsultationTrend> _buildGroupedTrend({
  required Iterable<DateTime?> dates,
  required DateTime startDate,
  required DateTime endDate,
  required ReportGrouping grouping,
}) {
  final counts = <DateTime, int>{};
  final endExclusive = endDate.add(const Duration(days: 1));
  for (final date in dates) {
    if (date == null || !_isInRange(date, startDate, endExclusive)) continue;
    final bucket = reportBucketStart(date, grouping);
    counts[bucket] = (counts[bucket] ?? 0) + 1;
  }

  final trends = <ConsultationTrend>[];
  var bucket = reportBucketStart(startDate, grouping);
  final lastBucket = reportBucketStart(endDate, grouping);
  while (!bucket.isAfter(lastBucket)) {
    trends.add(ConsultationTrend(date: bucket, count: counts[bucket] ?? 0));
    bucket = nextReportBucket(bucket, grouping);
  }
  return trends;
}

List<DistributionMetric> _buildDistribution(
  Map<String, int> counts, {
  int topN = 5,
}) {
  if (counts.isEmpty) return [];

  final total = counts.values.fold<int>(0, (sum, value) => sum + value);
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.take(topN).map((entry) {
    return DistributionMetric(
      label: entry.key,
      value: entry.value,
      percentage: total > 0 ? (entry.value / total) * 100 : 0,
    );
  }).toList();
}

String _patientCategoryLabel(Patient patient) {
  if (patient.category != null) return patient.category!.displayName;
  return patientCategoryFromDateOfBirth(patient.dateOfBirth)?.displayName ??
      'Uncategorized';
}

String _diagnosisLabel({required String? code, required String? description}) {
  if (code == null || code.isEmpty) return 'Unspecified';
  if (description == null || description.trim().isEmpty) return code;
  final short = description.trim();
  if (short.length <= 28) return '$code · $short';
  return '$code · ${short.substring(0, 25)}…';
}

/// Provider for report statistics
final reportStatsProvider = FutureProvider<ReportStats>((ref) async {
  ref.keepAlive();
  ref.watch(databaseChangesProvider);
  final filters = ref.watch(reportFiltersProvider);
  final db = ref.watch(databaseProvider);

  final consultations = await db.getAllConsultations();
  final patients = await db.getAllPatients();
  final queueItems = await db.getQueueItems();
  final documents = await db.getDocuments();

  final start = _startOfDay(filters.startDate);
  final end = _startOfDay(filters.endDate);
  final endExclusive = end.add(const Duration(days: 1));
  final days = end.difference(start).inDays + 1;
  final prevEndExclusive = start;
  final prevStart = start.subtract(Duration(days: days));

  final consultationsInRange = consultations
      .where((c) => _isInRange(c.createdAt, start, endExclusive))
      .toList();
  final consultationsPrevRange = consultations
      .where((c) => _isInRange(c.createdAt, prevStart, prevEndExclusive))
      .length;

  final patientsInRange = patients
      .where((p) => _isInRange(p.createdAt, start, endExclusive))
      .toList();
  final newPatientsInRange = patientsInRange.length;
  final newPatientsPrevRange = patients
      .where((p) => _isInRange(p.createdAt, prevStart, prevEndExclusive))
      .length;

  final followUpsInRange = consultationsInRange
      .where((c) => c.isFollowUp)
      .length;
  final followUpsPrevRange = consultations
      .where((c) => _isInRange(c.createdAt, prevStart, prevEndExclusive))
      .where((c) => c.isFollowUp)
      .length;

  final completedInRange = queueItems
      .where(
        (q) =>
            q.status == QueueStatus.completed &&
            _isInRange(
              q.endTime ?? q.updatedAt ?? q.arrivalTime,
              start,
              endExclusive,
            ),
      )
      .toList();
  final completedPrevRange = queueItems
      .where(
        (q) =>
            q.status == QueueStatus.completed &&
            _isInRange(
              q.endTime ?? q.updatedAt ?? q.arrivalTime,
              prevStart,
              prevEndExclusive,
            ),
      )
      .toList();

  final avgWait = _averageWaitMinutes(completedInRange);
  final avgWaitPrev = _averageWaitMinutes(completedPrevRange);

  final documentsInRange = documents
      .where((d) => _isInRange(d.createdAt, start, endExclusive))
      .length;

  final diagnosisCounts = <String, int>{};
  for (final consultation in consultationsInRange) {
    final label = _diagnosisLabel(
      code: consultation.icd10Code,
      description: consultation.icd10Description,
    );
    diagnosisCounts[label] = (diagnosisCounts[label] ?? 0) + 1;
  }

  final activePatients = patientsInRange.where((p) => !p.isArchived);
  final barangayCounts = <String, int>{};
  final categoryCounts = <String, int>{};
  for (final patient in activePatients) {
    final barangay = (patient.barangay?.trim().isNotEmpty == true)
        ? patient.barangay!.trim()
        : 'Unassigned';
    barangayCounts[barangay] = (barangayCounts[barangay] ?? 0) + 1;

    final category = _patientCategoryLabel(patient);
    categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
  }

  final consultationTrends = _buildGroupedTrend(
    dates: consultationsInRange.map((c) => c.createdAt),
    startDate: start,
    endDate: end,
    grouping: filters.grouping,
  );

  final newPatientTrends = _buildGroupedTrend(
    dates: patientsInRange.map((p) => p.createdAt),
    startDate: start,
    endDate: end,
    grouping: filters.grouping,
  );

  ConsultationTrend? peakDay;
  for (final trend in consultationTrends) {
    if (peakDay == null || trend.count > peakDay.count) {
      peakDay = trend;
    }
  }

  return ReportStats(
    rangeDays: days,
    grouping: filters.grouping,
    totalConsultations: consultationsInRange.length,
    newPatients: newPatientsInRange,
    followUps: followUpsInRange,
    avgWaitMinutes: avgWait,
    completedQueueVisits: completedInRange.length,
    documentsInRange: documentsInRange,
    topDiagnoses: _buildDistribution(diagnosisCounts, topN: 6),
    consultationTrends: consultationTrends,
    newPatientTrends: newPatientTrends,
    patientsByBarangay: _buildDistribution(barangayCounts, topN: 6),
    patientsByCategory: _buildDistribution(categoryCounts, topN: 6),
    consultationsDelta: _buildDelta(
      current: consultationsInRange.length,
      previous: consultationsPrevRange,
      lowerIsBetter: false,
    ),
    newPatientsDelta: _buildDelta(
      current: newPatientsInRange,
      previous: newPatientsPrevRange,
      lowerIsBetter: false,
    ),
    followUpsDelta: _buildDelta(
      current: followUpsInRange,
      previous: followUpsPrevRange,
      lowerIsBetter: false,
    ),
    avgWaitDelta: _buildDelta(
      current: avgWait,
      previous: avgWaitPrev,
      lowerIsBetter: true,
    ),
    peakConsultationLabel: peakDay != null
        ? _formatShortDate(peakDay.date)
        : null,
    peakConsultationCount: peakDay?.count ?? 0,
    timestamp: DateTime.now(),
  );
});

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

/// Provider for generated reports list
final generatedReportsProvider = FutureProvider<List<GeneratedReport>>((
  ref,
) async {
  ref.watch(databaseChangesProvider);
  final db = ref.watch(databaseProvider);
  return db.getGeneratedReports();
});
