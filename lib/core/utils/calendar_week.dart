/// Calendar boundaries, not fixed 24-hour durations (which cross DST wrongly).
abstract final class CalendarWeek {
  static DateTime start(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - 1));

  static DateTime end(DateTime day) {
    final monday = start(day);
    return DateTime(monday.year, monday.month, monday.day + 7);
  }
}
