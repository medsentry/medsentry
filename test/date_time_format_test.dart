import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/utils/date_time_format.dart';

void main() {
  test('formats local times with a 12-hour clock and AM/PM', () {
    expect(formatTime12h(DateTime(2026, 10, 1, 0, 0)), '12:00 AM');
    expect(formatTime12h(DateTime(2026, 10, 1, 9, 0)), '9:00 AM');
    expect(formatTime12h(DateTime(2026, 10, 1, 12, 5)), '12:05 PM');
    expect(formatTime12h(DateTime(2026, 10, 1, 18, 30)), '6:30 PM');
  });
}
