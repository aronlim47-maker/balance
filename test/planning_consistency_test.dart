import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/world_history_repository.dart';
import 'package:balance/domain/enums/task_status.dart';
import 'package:balance/domain/models/plan_reservation.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/usecases/daily_capacity.dart';
import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:balance/features/quests/quest_board_view_model.dart';
import 'package:balance/features/today/today_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completed and cancelled tasks release plan reservations', () {
    final day = DateTime(2026, 10, 1);
    for (final status in [TaskStatus.completed, TaskStatus.cancelled]) {
      final task = TaskItem(
        id: 'task',
        title: 'Report',
        estimatedMinutes: 60,
        dueAt: day,
        status: status,
      );
      final capacity = DailyCapacity.forDay(
        day: day,
        tasks: [task],
        availability: [],
        reservations: [
          PlanReservation(
            taskId: task.id,
            startAt: day,
            endAt: day.add(const Duration(hours: 1)),
          ),
        ],
      );
      expect(capacity.workMinutes, 0);
      expect(capacity.overloadMinutes, 0);
    }
  });

  test('duration changes preserve work already allocated by Council', () {
    final task = TaskItem(
      id: 'task',
      title: 'Report',
      estimatedMinutes: 120,
      remainingMinutes: 60,
      dueAt: DateTime(2026, 10, 2),
    );
    expect(task.remainingAfterEstimate(150), 90);
    expect(task.remainingAfterEstimate(90), 30);
    expect(task.remainingAfterEstimate(30), -30);
  });

  test('failed Quest Board refresh retains the loaded list', () async {
    final tasks = _Tasks();
    await tasks.createTask(
      TaskItem(
        id: '',
        title: 'Report',
        estimatedMinutes: 60,
        dueAt: DateTime.now(),
      ),
    );
    final vm = QuestBoardViewModel(tasks);
    await vm.loadTasks();
    tasks.failReads = true;
    await vm.loadTasks();
    expect(vm.tasks.single.title, 'Report');
    expect(vm.errorMessage, isNotNull);
    vm.dispose();
  });

  test(
    'historical World Status uses stored score despite task changes',
    () async {
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day - 1);
      final tasks = _Tasks();
      final history = _History();
      final vm = TodayViewModel(
        tasks,
        LocalAvailabilityRepository(),
        null,
        null,
        null,
        null,
        null,
        null,
        history,
      )..selectDay(day, reload: false);
      await vm.load();
      expect(vm.worldStatus.totalScore, 42);
      await tasks.createTask(
        TaskItem(id: '', title: 'New task', estimatedMinutes: 300, dueAt: day),
      );
      await vm.load();
      expect(vm.worldStatus.totalScore, 42);
      history.hasSnapshot = false;
      await vm.load();
      expect(vm.worldStatus.totalScore, isNull);
      expect(vm.worldStatus.knownDimensions, isEmpty);
      vm.dispose();
    },
  );
}

class _Tasks extends LocalTaskRepository {
  bool failReads = false;
  @override
  Future<List<TaskItem>> fetchTasks() {
    if (failReads) throw StateError('Read failed');
    return super.fetchTasks();
  }
}

class _History implements WorldHistoryRepository {
  bool hasSnapshot = true;
  @override
  Future<WorldStatusResult?> loadDaySnapshot(DateTime day) async => hasSnapshot
      ? WorldStatusResult.fromSnapshot({
          'mental_score': 42,
          'time_score': 42,
          'physical_score': 42,
          'social_score': 42,
          'errands_score': 42,
          'total_score': 42,
          'coverage': 1,
          'trend': 'stable',
        })
      : null;
  @override
  Future<List<int?>> loadPreviousWeek(DateTime selectedDay) async =>
      List.filled(7, null);
  @override
  Future<WeeklyJourney> loadWeek(DateTime weekStart) async => WeeklyJourney(
    weekStart: weekStart,
    dailyScores: List.filled(7, null),
    protectedRecoveryDays: 0,
  );
}
