import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/patient.dart';
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
  final int newPatients;
  final int documentsInRange;
  final List<ReportTrend> newPatientTrends;
  final List<DistributionMetric> patientsByBarangay;
  final List<DistributionMetric> patientsByCategory;
  final MetricDelta newPatientsDelta;
  final DateTime timestamp;

  ReportStats({
    required this.rangeDays,
    required this.grouping,
    required this.newPatients,
    required this.documentsInRange,
    required this.newPatientTrends,
    required this.patientsByBarangay,
    required this.patientsByCategory,
    required this.newPatientsDelta,
    required this.timestamp,
  });

  factory ReportStats.empty() => ReportStats(
    rangeDays: 30,
    grouping: ReportGrouping.day,
    newPatients: 0,
    documentsInRange: 0,
    newPatientTrends: [],
    patientsByBarangay: [],
    patientsByCategory: [],
    newPatientsDelta: MetricDelta.empty(),
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

class ReportTrend {
  final DateTime date;
  final int count;

  ReportTrend({required this.date, required this.count});
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

List<ReportTrend> _buildGroupedTrend({
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

  final trends = <ReportTrend>[];
  var bucket = reportBucketStart(startDate, grouping);
  final lastBucket = reportBucketStart(endDate, grouping);
  while (!bucket.isAfter(lastBucket)) {
    trends.add(ReportTrend(date: bucket, count: counts[bucket] ?? 0));
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

/// Provider for report statistics
final reportStatsProvider = FutureProvider<ReportStats>((ref) async {
  ref.keepAlive();
  ref.watch(databaseChangesProvider);
  final filters = ref.watch(reportFiltersProvider);
  final db = ref.watch(databaseProvider);

  final patients = await db.getAllPatients();
  final documents = await db.getDocuments();

  final start = _startOfDay(filters.startDate);
  final end = _startOfDay(filters.endDate);
  final endExclusive = end.add(const Duration(days: 1));
  final days = end.difference(start).inDays + 1;
  final prevEndExclusive = start;
  final prevStart = start.subtract(Duration(days: days));

  final patientsInRange = patients
      .where((p) => _isInRange(p.createdAt, start, endExclusive))
      .toList();
  final newPatientsInRange = patientsInRange.length;
  final newPatientsPrevRange = patients
      .where((p) => _isInRange(p.createdAt, prevStart, prevEndExclusive))
      .length;

  final documentsInRange = documents
      .where((d) => _isInRange(d.createdAt, start, endExclusive))
      .length;

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

  final newPatientTrends = _buildGroupedTrend(
    dates: patientsInRange.map((p) => p.createdAt),
    startDate: start,
    endDate: end,
    grouping: filters.grouping,
  );

  return ReportStats(
    rangeDays: days,
    grouping: filters.grouping,
    newPatients: newPatientsInRange,
    documentsInRange: documentsInRange,
    newPatientTrends: newPatientTrends,
    patientsByBarangay: _buildDistribution(barangayCounts, topN: 6),
    patientsByCategory: _buildDistribution(categoryCounts, topN: 6),
    newPatientsDelta: _buildDelta(
      current: newPatientsInRange,
      previous: newPatientsPrevRange,
      lowerIsBetter: false,
    ),
    timestamp: DateTime.now(),
  );
});

/// Provider for generated reports list
final generatedReportsProvider = FutureProvider<List<GeneratedReport>>((
  ref,
) async {
  ref.watch(databaseChangesProvider);
  final db = ref.watch(databaseProvider);
  return db.getGeneratedReports();
});
