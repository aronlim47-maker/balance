import 'dart:async';

import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/achievement_repository.dart';
import 'package:balance/data/mappers/task_mapper.dart';
import 'package:balance/core/utils/app_error_message.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/models/achievement_models.dart';
import 'package:balance/features/quests/quest_board_view_model.dart';
import 'package:balance/features/journey/journey_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old Quest refresh cannot erase a saved task', () async {
    final repository = _DelayedTasks();
    final model = QuestBoardViewModel(repository);
    final refresh = model.loadTasks();
    expect(await model.saveTask(_task()), isTrue);
    repository.pending.complete([]);
    await refresh;
    expect(model.tasks, hasLength(1));
    model.dispose();
  });

  test('Quest ignores a response after its page closes', () async {
    final repository = _DelayedTasks();
    final model = QuestBoardViewModel(repository);
    final refresh = model.loadTasks();
    model.dispose();
    repository.pending.complete([_task()]);
    await refresh;
    expect(model.tasks, isEmpty);
  });

  test(
    'a stale task version is rejected without overwriting the task',
    () async {
      final repository = LocalTaskRepository();
      final original = await repository.createTask(_task());
      final saved = await repository.updateTask(original);
      expect(saved.version, original.version + 1);
      await expectLater(repository.updateTask(original), throwsStateError);
      expect((await repository.fetchTasks()).single.version, saved.version);
      expect(
        AppErrorMessage.from(
          StateError('Task edit conflict'),
          fallback: 'Error',
        ),
        contains('Refresh'),
      );
    },
  );

  test('database task version is retained but not written by the client', () {
    final json = TaskMapper.toInsert(_task(), 'user');
    json['id'] = 'task';
    json['version'] = 8;
    final task = TaskMapper.fromJson(json);
    expect(task.version, 8);
    expect(TaskMapper.toUpdate(task).containsKey('version'), isFalse);
  });

  test(
    'Journey retains achievements during and after a failed refresh',
    () async {
      final repository = _Achievements();
      final model = JourneyViewModel(repository);
      repository.pending.complete(_snapshot());
      await model.load();
      expect(model.unlockedCount, 1);
      repository.pending = Completer<AchievementSnapshot>();
      final refresh = model.load();
      expect(model.unlockedCount, 1);
      repository.pending.completeError(StateError('Simulated failure'));
      await refresh;
      expect(model.unlockedCount, 1);
      expect(model.errorMessage, isNotNull);
      model.dispose();
    },
  );

  test('Journey ignores an achievement response after disposal', () async {
    final repository = _Achievements();
    final model = JourneyViewModel(repository);
    final refresh = model.load();
    model.dispose();
    repository.pending.complete(_snapshot());
    await refresh;
    expect(model.unlockedCount, 0);
  });
}

TaskItem _task() => TaskItem(
  id: '',
  title: 'Study',
  estimatedMinutes: 60,
  dueAt: DateTime.now().add(const Duration(days: 1)),
);

AchievementSnapshot _snapshot() => AchievementSnapshot(
  definitions: achievementV1Catalogue,
  awards: [AchievementAward(key: 'protected_rest', awardedAt: DateTime.now())],
);

class _DelayedTasks extends LocalTaskRepository {
  final pending = Completer<List<TaskItem>>();
  @override
  Future<List<TaskItem>> fetchTasks() => pending.future;
}

class _Achievements implements AchievementRepository {
  Completer<AchievementSnapshot> pending = Completer<AchievementSnapshot>();
  @override
  Future<AchievementSnapshot> fetchAchievements() => pending.future;
}
