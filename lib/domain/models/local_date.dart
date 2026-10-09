/// Calendar date in the profile's IANA time zone, never an instant in UTC.
class LocalDate implements Comparable<LocalDate> {
  LocalDate(int year, int month, int day)
    : value = DateTime.utc(year, month, day) {
    if (year < 1 ||
        year > 9999 ||
        value.year != year ||
        value.month != month ||
        value.day != day) {
      throw FormatException('Invalid calendar date');
    }
  }
  factory LocalDate.parse(String text) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      throw FormatException('Expected YYYY-MM-DD', text);
    }
    return LocalDate(
      int.parse(text.substring(0, 4)),
      int.parse(text.substring(5, 7)),
      int.parse(text.substring(8, 10)),
    );
  }
  final DateTime value;
  LocalDate addDays(int days) {
    final next = value.add(Duration(days: days));
    return LocalDate(next.year, next.month, next.day);
  }

  @override
  int compareTo(LocalDate other) => value.compareTo(other.value);
  @override
  String toString() => value.toIso8601String().substring(0, 10);
  @override
  bool operator ==(Object other) => other is LocalDate && value == other.value;
  @override
  int get hashCode => value.hashCode;
}
