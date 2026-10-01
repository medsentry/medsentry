import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/utils/report_date_filter.dart';

void main() {
  final now = DateTime(2026, 10, 1, 16, 30);

  test('builds quick date ranges with local calendar boundaries', () {
    final yesterday = ReportFilters.forPreset(
      ReportDatePreset.yesterday,
      now: now,
    );
    expect(yesterday.startDate, DateTime(2026, 9, 30));
    expect(yesterday.endDate, DateTime(2026, 9, 30));

    final lastWeek = ReportFilters.forPreset(
      ReportDatePreset.lastWeek,
      now: now,
    );
    expect(lastWeek.startDate, DateTime(2026, 9, 21));
    expect(lastWeek.endDate, DateTime(2026, 9, 27));

    final lastMonth = ReportFilters.forPreset(
      ReportDatePreset.lastMonth,
      now: now,
    );
    expect(lastMonth.startDate, DateTime(2026, 9, 1));
    expect(lastMonth.endDate, DateTime(2026, 9, 30));
  });

  test('aligns grouped buckets to Monday and calendar periods', () {
    final date = DateTime(2026, 10, 1);
    expect(reportBucketStart(date, ReportGrouping.week), DateTime(2026, 9, 28));
    expect(
      reportBucketStart(date, ReportGrouping.month),
      DateTime(2026, 10, 1),
    );
    expect(
      nextReportBucket(DateTime(2026, 12, 1), ReportGrouping.month),
      DateTime(2027, 1, 1),
    );
  });

  test('includes the full selected end date but excludes the next day', () {
    final start = DateTime(2026, 10, 1);
    final endExclusive = DateTime(2026, 11, 1);

    expect(
      isWithinReportInterval(
        DateTime(2026, 10, 31, 23, 59),
        start,
        endExclusive,
      ),
      isTrue,
    );
    expect(
      isWithinReportInterval(DateTime(2026, 11, 1), start, endExclusive),
      isFalse,
    );
  });
}
