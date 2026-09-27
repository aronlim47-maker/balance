import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/models/check_in.dart';
import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:balance/features/today/today_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates planned, available and overload minutes', () async {
    final tasks = LocalTaskRepository();
    final availability = LocalAvailabilityRepository();
    final day = DateTime(2026, 9, 30);
    await tasks.createTask(
      TaskItem(
        id: '',
        title: 'Build demo',
        estimatedMinutes: 300,
        dueAt: DateTime(2026, 9, 30, 17),
      ),
    );
    await availability.createAvailability(
      AvailabilityBlock(
        id: '',
        startAt: DateTime(2026, 9, 30, 9),
        endAt: DateTime(2026, 9, 30, 12),
        isAvailable: true,
      ),
    );
    final viewModel = TodayViewModel(tasks, availability)..selectDay(day);

    await viewModel.load();

    expect(viewModel.plannedMinutes, 300);
    expect(viewModel.availableMinutes, 180);
    expect(viewModel.overloadMinutes, 120);
    expect(
      viewModel.worldStatus.dimensions[WorldDimension.time]!.score,
      isNotNull,
    );
    expect(
      viewModel.worldStatus.dimensions[WorldDimension.errands]!.score,
      isNull,
    );
    expect(
      viewModel.worldStatus.dimensions[WorldDimension.physical]!.score,
      isNull,
    );
    expect(
      viewModel.worldStatus.dimensions[WorldDimension.social]!.score,
      isNull,
    );
    expect(viewModel.worldStatus.totalScore, isNull);
    expect(viewModel.worldStatus.label, 'Not enough data');
  });

  test('creates and deletes availability blocks', () async {
    final viewModel = TodayViewModel(
      LocalTaskRepository(),
      LocalAvailabilityRepository(),
    )..selectDay(DateTime(2026, 9, 30));
    await viewModel.load();

    final saved = await viewModel.saveAvailability(
      AvailabilityBlock(
        id: '',
        startAt: DateTime(2026, 9, 30, 9),
        endAt: DateTime(2026, 9, 30, 10),
        isAvailable: true,
      ),
    );
    final blockId = viewModel.availabilityForDay.single.id;
    final deleted = await viewModel.deleteAvailability(blockId);

    expect(saved, isTrue);
    expect(deleted, isTrue);
    expect(viewModel.availabilityForDay, isEmpty);
  });

  test(
    'explicit category makes Errands known without inventing activity data',
    () async {
      final tasks = LocalTaskRepository();
      final availability = LocalAvailabilityRepository();
      final day = DateTime(2026, 9, 30);
      await tasks.createTask(
        TaskItem(
          id: '',
          title: 'Course assignment',
          estimatedMinutes: 60,
          dueAt: DateTime(2026, 9, 30, 17),
          loadCategory: LoadCategory.study,
        ),
      );
      await availability.createAvailability(
        AvailabilityBlock(
          id: '',
          startAt: DateTime(2026, 9, 30, 9),
          endAt: DateTime(2026, 9, 30, 11),
          isAvailable: true,
        ),
      );
      final viewModel = TodayViewModel(tasks, availability)..selectDay(day);
      await viewModel.load();

      expect(
        viewModel.worldStatus.dimensions[WorldDimension.errands]!.score,
        0,
      );
      expect(viewModel.worldStatus.totalScore, isNotNull);
      expect(viewModel.worldStatus.isPartial, true);
      expect(
        viewModel.worldStatus.dimensions[WorldDimension.social]!.score,
        isNull,
      );
    },
  );

  test(
    'saving optional energy changes Mental without inventing Physical',
    () async {
      final tasks = LocalTaskRepository();
      final availability = LocalAvailabilityRepository();
      final reviews = LocalCheckInRepository();
      final day = DateTime(2026, 9, 30);
      await tasks.createTask(
        TaskItem(
          id: '',
          title: 'Study',
          estimatedMinutes: 60,
          dueAt: DateTime(2026, 9, 30, 17),
          loadCategory: LoadCategory.study,
        ),
      );
      await availability.createAvailability(
        AvailabilityBlock(
          id: '',
          startAt: DateTime(2026, 9, 30, 9),
          endAt: DateTime(2026, 9, 30, 11),
          isAvailable: true,
        ),
      );
      final viewModel = TodayViewModel(
        tasks,
        availability,
        null,
        null,
        null,
        reviews,
      )..selectDay(day);
      await viewModel.load();
      final before =
          viewModel.worldStatus.dimensions[WorldDimension.mental]!.score;

      expect(
        await viewModel.saveDailyReview(
          CheckIn(date: day, mentalEnergyLevel: EnergyLevel.moderate),
        ),
        isTrue,
      );
      expect(
        viewModel.worldStatus.dimensions[WorldDimension.mental]!.score,
        isNot(before),
      );
      expect(
        viewModel.worldStatus.dimensions[WorldDimension.physical]!.score,
        isNull,
      );
      expect(
        (await reviews.fetchCheckIn(day))!.mentalEnergyLevel,
        EnergyLevel.moderate,
      );
    },
  );
}
