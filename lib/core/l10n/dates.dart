import 'package:intl/intl.dart';

import 'tr.dart';

/// Short dates and times written by hand in English ("Wed 14 Oct", "9:00 AM")
/// and with the language's own format otherwise ("10月14日周三", "上午9:00").
///
/// English keeps the exact text the app always showed, so messages built from
/// these values still match their English keys.
abstract final class AppDates {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
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

  static bool get _english => Tr.language == AppLanguage.english;

  /// "Wed 14 Oct".
  static String weekdayDayMonth(DateTime date) => _english
      ? '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}'
      : DateFormat.MMMEd().format(date);

  /// "14 Oct".
  static String dayMonth(DateTime date) => _english
      ? '${date.day} ${_months[date.month - 1]}'
      : DateFormat.MMMd().format(date);

  /// "Wed".
  static String weekday(DateTime date) =>
      _english ? _weekdays[date.weekday - 1] : DateFormat.E().format(date);

  /// "9:00 AM" in the phone's local time.
  static String clock(DateTime time) {
    final local = time.toLocal();
    if (!_english) return DateFormat.jm().format(local);
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
  }

  /// [englishPattern] in English (unchanged look), otherwise the locale's own
  /// format for the same fields.
  static DateFormat format(
    String englishPattern,
    DateFormat Function() localized,
  ) => _english ? DateFormat(englishPattern) : localized();
}
