import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/plan_repository.dart';
import 'package:balance/data/repositories/world_history_repository.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/check_in.dart';
import 'package:balance/domain/models/plan_reservation.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/enums/task_status.dart';
import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:balance/features/today/today_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 10, 4);
  test(
    'moved work is visible on destination, inactive tasks stay hidden',
    () async {
      final tasks = LocalTaskRepository();
      final task = await tasks.createTask(
        TaskItem(
          id: '',
          title: 'Moved study',
          estimatedMinutes: 180,
          remainingMinutes: 60,
          dueAt: day.add(const Duration(days: 3)),
          scheduledStart: day
              .subtract(const Duration(days: 1))
              .add(const Duration(hours: 9)),
          scheduledEnd: day
              .subtract(const Duration(days: 1))
              .add(const Duration(hours: 10)),
        ),
      );
      final plans = _Plans([
        PlanReservation(
          taskId: task.id,
          startAt: day.add(const Duration(hours: 9)),
          endAt: day.add(const Duration(hours: 11)),
        ),
      ]);
      final model = TodayViewModel(tasks, LocalAvailabilityRepository(), plans);
      model.selectDay(day, reload: false);
      await model.load();
      expect(model.tasksForDay.single.id, task.id);
      expect(model.reservationsForTask(task), hasLength(1));
      expect(model.plannedMinutes, 120);
      await tasks.updateTask(
        TaskItem(
          id: task.id,
          title: task.title,
          estimatedMinutes: 180,
          dueAt: task.dueAt,
          status: TaskStatus.completed,
        ),
      );
      await model.load();
      expect(model.tasksForDay, isEmpty);
      expect(model.plannedMinutes, 0);
      model.dispose();
    },
  );

  test('review and availability changes capture history; capture failure is not save failure', () async {
    final history = _History();
    final model = TodayViewModel(
      LocalTaskRepository(),
      LocalAvailabilityRepository(),
      null,
      null,
      null,
      LocalCheckInRepository(),
      null,
      null,
      history,
    );
    expect(
      await model.saveDailyReview(CheckIn(date: DateTime.now(), sleepHours: 8)),
      isTrue,
    );
    expect(history.captures, 1);
    history.fail = true;
    expect(
      await model.saveAvailability(
        AvailabilityBlock(
          id: '',
          startAt: day,
          endAt: day.add(const Duration(hours: 1)),
          isAvailable: true,
        ),
      ),
      isTrue,
    );
    expect(model.allAvailability, hasLength(1));
    expect(model.refreshWarning, contains('Saved, but'));
    history.fail = false;
    expect(
      await model.deleteAvailability(model.allAvailability.single.id),
      isTrue,
    );
    expect(history.captures, 3);
    expect(model.refreshWarning, isNull);
    model.dispose();
  });
}

class _Plans implements PlanRepository {
  _Plans(this.reservations);
  final List<PlanReservation> reservations;
  @override
  Future<List<PlanReservation>> fetchPlanReservations() async => reservations;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _History implements WorldHistoryRepository {
  int captures = 0;
  bool fail = false;
  @override
  Future<List<int?>> loadPreviousWeek(DateTime day) async {
    captures++;
    if (fail) throw StateError('Read failed');
    return List.filled(7, null);
  }

  @override
  Future<WorldStatusResult?> loadDaySnapshot(DateTime day) async => null;
  @override
  Future<WeeklyJourney> loadWeek(DateTime day) async =>
      throw UnimplementedError();
}
