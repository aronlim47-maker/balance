import 'dart:async';

import 'package:balance/core/utils/app_error_message.dart';
import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/achievement_repository.dart';
import 'package:balance/domain/models/achievement_models.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/check_in.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/features/today/today_view_model.dart';
import 'package:balance/features/journey/journey_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'old Today refresh cannot remove a newly saved availability block',
    () async {
      final tasks = _Tasks();
      final model = TodayViewModel(tasks, LocalAvailabilityRepository());
      final loading = model.load();
      expect(await model.saveAvailability(_block()), isTrue);
      tasks.pending.complete([]);
      await loading;
      expect(model.allAvailability, hasLength(1));
      model.dispose();
    },
  );

  test(
    'old Today refresh cannot restore a deleted availability block',
    () async {
      final tasks = _Tasks();
      final availability = LocalAvailabilityRepository();
      final block = await availability.createAvailability(_block());
      final model = TodayViewModel(tasks, availability);
      final loading = model.load();
      expect(await model.deleteAvailability(block.id), isTrue);
      tasks.pending.complete([]);
      await loading;
      expect(model.allAvailability, isEmpty);
      expect(await availability.fetchAvailability(), isEmpty);
      model.dispose();
    },
  );

  test('old Today refresh cannot overwrite a saved Daily Review', () async {
    final tasks = _Tasks();
    final model = TodayViewModel(
      tasks,
      LocalAvailabilityRepository(),
      null,
      null,
      null,
      LocalCheckInRepository(),
    );
    final loading = model.load();
    final review = CheckIn(date: DateTime.now(), sleepHours: 8);
    expect(await model.saveDailyReview(review), isTrue);
    tasks.pending.complete([]);
    await loading;
    expect(model.checkIn?.sleepHours, 8);
    model.dispose();
  });

  test(
    'reflection copy distinguishes refresh failure from successful refresh',
    () async {
      final repository = _Achievements();
      final model = JourneyViewModel(repository);
      await model.load();
      expect(model.reflectionSavedMessage, 'Reflection saved.');
      repository.fail = true;
      await model.load();
      expect(model.reflectionSavedMessage, contains('saved, but'));
      model.dispose();
    },
  );

  test('unconfirmed deletion has safe and actionable copy', () {
    final message = AppErrorMessage.from(
      StateError('Deletion not confirmed'),
      fallback: 'Failed',
    );
    expect(message, contains('Refresh'));
    expect(message, isNot(contains('StateError')));
  });
}

AvailabilityBlock _block() => AvailabilityBlock(
  id: '',
  startAt: DateTime.now(),
  endAt: DateTime.now().add(const Duration(hours: 1)),
  isAvailable: true,
);

class _Tasks extends LocalTaskRepository {
  final pending = Completer<List<TaskItem>>();
  @override
  Future<List<TaskItem>> fetchTasks() => pending.future;
}

class _Achievements implements AchievementRepository {
  bool fail = false;
  @override
  Future<AchievementSnapshot> fetchAchievements() async {
    if (fail) throw StateError('Simulated read failure');
    return const AchievementSnapshot(
      definitions: achievementV1Catalogue,
      awards: [],
    );
  }
}
