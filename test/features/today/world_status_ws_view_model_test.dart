// View-model evidence for WS09 and WS12 (Rev7 14.4.7). Covers Matthew's part.
import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/domain/enums/task_status.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/movement_models.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:balance/features/today/today_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  test(
    'WS09 a failed refresh shows a safe error and keeps the last values',
        () async {
      final tasks = _ReadFailingTasks();
      final availability = LocalAvailabilityRepository();
      await tasks.createTask(
        TaskItem(
          id: '',
          title: 'Build demo',
          estimatedMinutes: 300,
          dueAt: today.add(const Duration(hours: 17)),
          loadCategory: LoadCategory.study,
        ),
      );
      await availability.createAvailability(
        AvailabilityBlock(
          id: '',
          startAt: today.add(const Duration(hours: 9)),
          endAt: today.add(const Duration(hours: 12)),
          isAvailable: true,
        ),
      );
      final viewModel = TodayViewModel(tasks, availability)..selectDay(today);
      await viewModel.load();
      final before = viewModel.worldStatus;
      final timeBefore = before.dimensions[WorldDimension.time]!.score;
      expect(timeBefore, isNotNull);
      expect(viewModel.errorMessage, isNull);

      tasks.failReads = true;
      await viewModel.load();

      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.errorMessage, isNot(contains('Simulated')));
      expect(viewModel.tasksForDay, hasLength(1));
      expect(viewModel.plannedMinutes, 300);
      final after = viewModel.worldStatus;
      expect(after.dimensions[WorldDimension.time]!.score, timeBefore);
      expect(after.dimensions[WorldDimension.errands]!.score, 0);

      tasks.failReads = false;
      await viewModel.load();
      expect(viewModel.errorMessage, isNull);
      viewModel.dispose();
    },
  );

  test(
    'WS12 completing an Exercise task alone leaves Physical unchanged',
        () async {
      final tasks = LocalTaskRepository();
      final movement = LocalMovementRepository();
      final exercise = await tasks.createTask(
        TaskItem(
          id: '',
          title: 'Badminton',
          estimatedMinutes: 60,
          dueAt: today.add(const Duration(hours: 20)),
          loadCategory: LoadCategory.exercise,
          status: TaskStatus.completed,
        ),
      );
      final viewModel = TodayViewModel(
        tasks,
        LocalAvailabilityRepository(),
        null,
        null,
        null,
        null,
        movement,
      )..selectDay(today);
      await viewModel.load();
      expect(
        await viewModel.saveMovementSettings(
          const MovementSettings(trackingEnabled: true),
        ),
        isTrue,
        reason: viewModel.errorMessage,
      );

      // The task is completed, but no exercise was confirmed.
      expect(viewModel.exerciseTasks.single.id, exercise.id);
      expect(viewModel.latestExercise, isNull);
      expect(
        viewModel.worldStatus.dimensions[WorldDimension.physical]!.score,
        isNull,
      );

      // Confirming one linked record updates Physical once.
      expect(
        await viewModel.recordExercise(
          ExerciseLog(
            id: '',
            occurredAt: today,
            durationMinutes: 45,
            taskId: exercise.id,
          ),
        ),
        isTrue,
        reason: viewModel.errorMessage,
      );
      expect(viewModel.exerciseLogsForDay, hasLength(1));
      expect(viewModel.exerciseLogsForDay.single.taskId, exercise.id);
      expect(
        viewModel.worldStatus.dimensions[WorldDimension.physical]!.score,
        isNotNull,
      );
      viewModel.dispose();
    },
  );
}

class _ReadFailingTasks extends LocalTaskRepository {
  bool failReads = false;
  @override
  Future<List<TaskItem>> fetchTasks() {
    if (failReads) throw StateError('Simulated read failure');
    return super.fetchTasks();
  }
}