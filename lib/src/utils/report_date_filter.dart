enum ReportDatePreset {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisYear,
  lastYear,
  custom,
}

extension ReportDatePresetLabel on ReportDatePreset {
  String get label => switch (this) {
    ReportDatePreset.today => 'Today',
    ReportDatePreset.yesterday => 'Yesterday',
    ReportDatePreset.thisWeek => 'This Week',
    ReportDatePreset.lastWeek => 'Last Week',
    ReportDatePreset.thisMonth => 'This Month',
    ReportDatePreset.lastMonth => 'Last Month',
    ReportDatePreset.thisYear => 'This Year',
    ReportDatePreset.lastYear => 'Last Year',
    ReportDatePreset.custom => 'Custom Range',
  };
}

enum ReportGrouping { day, week, month, year }

extension ReportGroupingLabel on ReportGrouping {
  String get label => switch (this) {
    ReportGrouping.day => 'Day',
    ReportGrouping.week => 'Week',
    ReportGrouping.month => 'Month',
    ReportGrouping.year => 'Year',
  };
}

class ReportFilters {
  final ReportDatePreset preset;
  final DateTime startDate;
  final DateTime endDate;
  final ReportGrouping grouping;

  const ReportFilters({
    required this.preset,
    required this.startDate,
    required this.endDate,
    required this.grouping,
  });

  factory ReportFilters.forPreset(
    ReportDatePreset preset, {
    DateTime? now,
    ReportGrouping grouping = ReportGrouping.day,
  }) {
    final today = _startOfDay((now ?? DateTime.now()).toLocal());
    late final DateTime start;
    late final DateTime end;

    switch (preset) {
      case ReportDatePreset.today:
        start = today;
        end = today;
      case ReportDatePreset.yesterday:
        start = today.subtract(const Duration(days: 1));
        end = start;
      case ReportDatePreset.thisWeek:
        start = today.subtract(Duration(days: today.weekday - 1));
        end = today;
      case ReportDatePreset.lastWeek:
        end = today.subtract(Duration(days: today.weekday));
        start = end.subtract(const Duration(days: 6));
      case ReportDatePreset.thisMonth:
        start = DateTime(today.year, today.month);
        end = today;
      case ReportDatePreset.lastMonth:
        start = DateTime(today.year, today.month - 1);
        end = DateTime(today.year, today.month, 0);
      case ReportDatePreset.thisYear:
        start = DateTime(today.year);
        end = today;
      case ReportDatePreset.lastYear:
        start = DateTime(today.year - 1);
        end = DateTime(today.year, 1, 0);
      case ReportDatePreset.custom:
        start = today;
        end = today;
    }

    return ReportFilters(
      preset: preset,
      startDate: start,
      endDate: end,
      grouping: grouping,
    );
  }

  ReportFilters copyWith({
    ReportDatePreset? preset,
    DateTime? startDate,
    DateTime? endDate,
    ReportGrouping? grouping,
  }) {
    return ReportFilters(
      preset: preset ?? this.preset,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      grouping: grouping ?? this.grouping,
    );
  }
}

DateTime reportBucketStart(DateTime date, ReportGrouping grouping) {
  final localDate = _startOfDay(date.toLocal());
  return switch (grouping) {
    ReportGrouping.day => localDate,
    ReportGrouping.week => localDate.subtract(
      Duration(days: localDate.weekday - 1),
    ),
    ReportGrouping.month => DateTime(localDate.year, localDate.month),
    ReportGrouping.year => DateTime(localDate.year),
  };
}

DateTime nextReportBucket(DateTime date, ReportGrouping grouping) {
  return switch (grouping) {
    ReportGrouping.day => date.add(const Duration(days: 1)),
    ReportGrouping.week => date.add(const Duration(days: 7)),
    ReportGrouping.month => DateTime(date.year, date.month + 1),
    ReportGrouping.year => DateTime(date.year + 1),
  };
}

bool isWithinReportInterval(
  DateTime? value,
  DateTime startInclusive,
  DateTime endExclusive,
) {
  if (value == null) return false;
  final localValue = value.toLocal();
  return !localValue.isBefore(startInclusive) &&
      localValue.isBefore(endExclusive);
}

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);
