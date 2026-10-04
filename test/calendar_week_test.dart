import 'package:balance/core/utils/calendar_week.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Monday and exclusive next Monday are calendar midnights', () {
    for (final day in [DateTime(2026, 3, 8, 15), DateTime(2026, 11, 1, 15)]) {
      final start = CalendarWeek.start(day);
      final end = CalendarWeek.end(day);
      expect(start.weekday, DateTime.monday);
      expect(end.weekday, DateTime.monday);
      expect(start.hour, 0);
      expect(end.hour, 0);
      expect(start, DateTime(day.year, day.month, day.day - day.weekday + 1));
      expect(end, DateTime(start.year, start.month, start.day + 7));
    }
  });
  test('Calendar week crosses year boundary correctly', () {
    expect(CalendarWeek.start(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
    expect(CalendarWeek.end(DateTime(2027, 1, 1)), DateTime(2027, 1, 4));
  });
}
