import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/recovery_repository.dart';
import 'package:balance/domain/models/recovery_slot.dart';
import 'package:balance/features/today/today_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 11, 1);

  test('Today lists the day\'s rest time, earliest first', () async {
    final recovery = _Recovery([
      RecoverySlot(
        id: 'evening',
        startAt: day.add(const Duration(hours: 19)),
        endAt: day.add(const Duration(hours: 19, minutes: 30)),
      ),
      RecoverySlot(
        id: 'next-day',
        startAt: day.add(const Duration(days: 1, hours: 9)),
        endAt: day.add(const Duration(days: 1, hours: 10)),
      ),
      RecoverySlot(
        id: 'morning',
        startAt: day.add(const Duration(hours: 7)),
        endAt: day.add(const Duration(hours: 7, minutes: 20)),
        selectedActivity: 'Short walk',
      ),
    ]);
    final model = TodayViewModel(
      LocalTaskRepository(),
      LocalAvailabilityRepository(),
      null,
      recovery,
    );
    model.selectDay(day, reload: false);
    await model.load();

    expect(model.recoverySlotsForDay.map((s) => s.id), ['morning', 'evening']);
    expect(model.recoveryMinutesForDay, 50);

    model.selectDay(day.add(const Duration(days: 1)), reload: false);
    expect(model.recoverySlotsForDay.map((s) => s.id), ['next-day']);
    expect(model.recoveryMinutesForDay, 60);
    model.dispose();
  });

  test('a day with no rest time shows none', () async {
    final model = TodayViewModel(
      LocalTaskRepository(),
      LocalAvailabilityRepository(),
      null,
      _Recovery(const []),
    );
    model.selectDay(day, reload: false);
    await model.load();
    expect(model.recoverySlotsForDay, isEmpty);
    expect(model.recoveryMinutesForDay, 0);
    model.dispose();
  });
}

class _Recovery implements RecoveryRepository {
  _Recovery(this.slots);
  final List<RecoverySlot> slots;

  @override
  Future<List<RecoverySlot>> fetchRecoverySlots() async => slots;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
