import 'package:flutter/foundation.dart';

class PlanningDayController extends ChangeNotifier {
  DateTime _selectedDay = _dayOnly(DateTime.now());

  DateTime get selectedDay => _selectedDay;

  void selectDay(DateTime day) {
    final next = _dayOnly(day);
    if (next == _selectedDay) return;
    _selectedDay = next;
    notifyListeners();
  }

  static DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
