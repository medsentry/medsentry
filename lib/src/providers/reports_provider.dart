import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/patient.dart';
import '../models/queue.dart';
import '../models/generated_report.dart';
import 'providers.dart';

/// Selected analytics window (7, 30, or 90 days).
final reportRangeDaysProvider = StateProvider<int>((ref) => 30);

/// Report statistics model
class ReportStats {
  final int rangeDays;
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

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

bool _isOnOrAfter(DateTime date, DateTime start) =>
    !_startOfDay(date).isBefore(_startOfDay(start));

bool _isOnOrBefore(DateTime date, DateTime end) =>
    !_startOfDay(date).isAfter(_startOfDay(end));

bool _isInRange(DateTime? date, DateTime start, DateTime end) {
  if (date == null) return false;
  return _isOnOrAfter(date, start) && _isOnOrBefore(date, end);
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

List<ConsultationTrend> _buildDailyTrend({
  required int totalDays,
  required DateTime endDate,
  required int Function(DateTime day) counter,
}) {
  final trends = <ConsultationTrend>[];
  for (int i = totalDays - 1; i >= 0; i--) {
    final date = _startOfDay(endDate.subtract(Duration(days: i)));
    trends.add(ConsultationTrend(date: date, count: counter(date)));
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

String _diagnosisLabel({
  required String? code,
  required String? description,
}) {
  if (code == null || code.isEmpty) return 'Unspecified';
  if (description == null || description.trim().isEmpty) return code;
  final short = description.trim();
  if (short.length <= 28) return '$code · $short';
  return '$code · ${short.substring(0, 25)}…';
}

/// Provider for report statistics
final reportStatsProvider = FutureProvider<ReportStats>((ref) async {
  ref.keepAlive();
  final days = ref.watch(reportRangeDaysProvider);
  final db = ref.watch(databaseProvider);

  final consultations = await db.getAllConsultations();
  final patients = await db.getAllPatients();
  final queueItems = await db.getQueueItems();
  final documents = await db.getDocuments();

  final now = DateTime.now();
  final end = _startOfDay(now);
  final start = _startOfDay(end.subtract(Duration(days: days - 1)));
  final prevEnd = _startOfDay(start.subtract(const Duration(days: 1)));
  final prevStart = _startOfDay(prevEnd.subtract(Duration(days: days - 1)));

  final consultationsInRange = consultations
      .where((c) => _isInRange(c.createdAt, start, end))
      .toList();
  final consultationsPrevRange = consultations
      .where((c) => _isInRange(c.createdAt, prevStart, prevEnd))
      .length;

  final newPatientsInRange = patients
      .where((p) => _isInRange(p.createdAt, start, end))
      .length;
  final newPatientsPrevRange = patients
      .where((p) => _isInRange(p.createdAt, prevStart, prevEnd))
      .length;

  final followUpsInRange =
      consultationsInRange.where((c) => c.isFollowUp).length;
  final followUpsPrevRange = consultations
      .where((c) => _isInRange(c.createdAt, prevStart, prevEnd))
      .where((c) => c.isFollowUp)
      .length;

  final completedInRange = queueItems
      .where(
        (q) =>
            q.status == QueueStatus.completed &&
            _isInRange(q.endTime ?? q.updatedAt ?? q.arrivalTime, start, end),
      )
      .toList();
  final completedPrevRange = queueItems
      .where(
        (q) =>
            q.status == QueueStatus.completed &&
            _isInRange(
              q.endTime ?? q.updatedAt ?? q.arrivalTime,
              prevStart,
              prevEnd,
            ),
      )
      .toList();

  final avgWait = _averageWaitMinutes(completedInRange);
  final avgWaitPrev = _averageWaitMinutes(completedPrevRange);

  final documentsInRange = documents
      .where((d) => _isInRange(d.createdAt, start, end))
      .length;

  final diagnosisCounts = <String, int>{};
  for (final consultation in consultationsInRange) {
    final label = _diagnosisLabel(
      code: consultation.icd10Code,
      description: consultation.icd10Description,
    );
    diagnosisCounts[label] = (diagnosisCounts[label] ?? 0) + 1;
  }

  final activePatients = patients.where((p) => !p.isArchived);
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

  final consultationTrends = _buildDailyTrend(
    totalDays: 90,
    endDate: end,
    counter: (day) => consultations.where((c) {
      final createdAt = c.createdAt;
      if (createdAt == null) return false;
      return _startOfDay(createdAt) == day;
    }).length,
  );

  final newPatientTrends = _buildDailyTrend(
    totalDays: 90,
    endDate: end,
    counter: (day) => patients.where((p) {
      final createdAt = p.createdAt;
      if (createdAt == null) return false;
      return _startOfDay(createdAt) == day;
    }).length,
  );

  ConsultationTrend? peakDay;
  for (final trend in consultationTrends) {
    if (_isInRange(trend.date, start, end) &&
        (peakDay == null || trend.count > peakDay.count)) {
      peakDay = trend;
    }
  }

  return ReportStats(
    rangeDays: days,
    totalConsultations: consultationsInRange.length,
    newPatients: newPatientsInRange,
    followUps: followUpsInRange,
    avgWaitMinutes: avgWait,
    completedQueueVisits: completedInRange.length,
    documentsInRange: documentsInRange,
    topDiagnoses: _buildDistribution(
      diagnosisCounts,
      topN: 6,
    ),
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
    peakConsultationLabel: peakDay != null ? _formatShortDate(peakDay.date) : null,
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
  final db = ref.watch(databaseProvider);
  return db.getGeneratedReports();
});
