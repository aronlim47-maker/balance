import 'dart:async';

import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/reminding_task_repository.dart';
import 'package:balance/data/services/device_reminder_gateway.dart';
import 'package:balance/domain/enums/task_status.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/usecases/plan_task_reminders.dart';
import 'package:balance/features/reminders/reminder_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

TaskItem task(
  String id,
  DateTime due, {
  TaskStatus status = TaskStatus.planned,
}) => TaskItem(
  id: id,
  title: 'Private title',
  estimatedMinutes: 30,
  dueAt: due,
  status: status,
);

class MemoryStore implements ReminderStore {
  final values = <String, ReminderPreferences>{};
  @override
  Future<ReminderPreferences> read(String owner) async =>
      values[owner] ?? const ReminderPreferences();
  @override
  Future<void> write(String owner, ReminderPreferences preferences) async {
    values[owner] = preferences;
  }
}

class FailingReadTasks extends LocalTaskRepository {
  bool failRead = false;
  @override
  Future<List<TaskItem>> fetchTasks() {
    if (failRead) throw StateError('private network error');
    return super.fetchTasks();
  }
}

class FakeGateway implements ReminderGateway {
  bool allowed = true;
  bool failSchedule = false;
  int requests = 0;
  Completer<void>? scheduleGate;
  final scheduled = <TaskReminder>[];
  @override
  bool get supported => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<tz.Location> location() async => tz.UTC;
  @override
  Future<bool> permission({bool request = false}) async {
    if (request) requests++;
    return allowed;
  }

  @override
  Future<void> cancelAll() async {
    scheduled.clear();
  }

  @override
  Future<void> schedule(int id, TaskReminder reminder) async {
    if (failSchedule) throw StateError('raw private platform error');
    await scheduleGate?.future;
    scheduled.add(reminder);
  }
}

void main() {
  setUpAll(tzdata.initializeTimeZones);
  final now = DateTime.utc(2026, 10, 4, 0);
  const enabled = ReminderPreferences(enabled: true, quietEnabled: false);

  test('Off by default, past/completed/cancelled excluded and duplicate IDs deduplicated', () {
    final tasks = [
      task('a', now.add(const Duration(hours: 2))),
      task('a', now.add(const Duration(hours: 2))),
      task('past', now),
      task(
        'completed',
        now.add(const Duration(hours: 3)),
        status: TaskStatus.completed,
      ),
      task(
        'cancelled',
        now.add(const Duration(hours: 3)),
        status: TaskStatus.cancelled,
      ),
    ];
    expect(
      planTaskReminders(tasks, const ReminderPreferences(), now, tz.UTC),
      isEmpty,
    );
    final reminders = planTaskReminders(tasks, enabled, now, tz.UTC);
    expect(reminders.map((r) => r.taskId), ['a']);
    expect(reminders.single.at.toUtc(), now.add(const Duration(minutes: 90)));
  });

  test(
    'Quiet hours use device zone, with inclusive start and exclusive end',
    () {
      final zone = tz.getLocation('Asia/Kuala_Lumpur');
      final tasks = [
        task('start', DateTime.utc(2026, 10, 4, 14, 30)),
        task('end', DateTime.utc(2026, 10, 5, 0, 30)),
        task('middle', DateTime.utc(2026, 10, 4, 18)),
      ];
      expect(
        planTaskReminders(
          tasks,
          const ReminderPreferences(enabled: true),
          now,
          zone,
        ).map((r) => r.taskId),
        ['end'],
      );
    },
  );

  test('Same-day quiet hours, equal endpoints invalid, limit nearest 50', () {
    final tasks = List.generate(
      65,
      (i) => task('$i', now.add(Duration(hours: i + 1))),
    );
    expect(planTaskReminders(tasks, enabled, now, tz.UTC), hasLength(50));
    expect(
      planTaskReminders(
        tasks,
        enabled.copyWith(quietEnabled: true, quietStart: 0, quietEnd: 0),
        now,
        tz.UTC,
      ),
      isEmpty,
    );
    final result = planTaskReminders(
      tasks,
      enabled.copyWith(quietEnabled: true, quietStart: 60, quietEnd: 180),
      now,
      tz.UTC,
    );
    expect(result.any((r) => r.at.hour == 1 || r.at.hour == 2), isFalse);
  });

  test('DST conversion preserves the deadline-minus-lead instant', () {
    final due = DateTime.utc(2026, 11, 1, 6, 15);
    final result = planTaskReminders(
      [task('dst', due)],
      enabled,
      now,
      tz.getLocation('America/New_York'),
    );
    expect(result.single.at.toUtc(), due.subtract(const Duration(minutes: 30)));
  });

  test('Startup does not request permission; denied enabling never persists enabled', () async {
    final gateway = FakeGateway()..allowed = false;
    final store = MemoryStore();
    final controller = ReminderController(
      LocalTaskRepository(),
      gateway,
      store,
    );
    addTearDown(controller.dispose);
    await controller.setOwner('a');
    expect(gateway.requests, 0);
    await controller.save(enabled);
    expect(gateway.requests, 1);
    expect(controller.preferences.enabled, isFalse);
    expect(store.values, isEmpty);
    expect(controller.message, contains('blocked'));
  });

  test('Create/edit/complete/delete reconcile; disable and signout clear notifications', () async {
    final inner = LocalTaskRepository();
    final gateway = FakeGateway();
    final controller = ReminderController(inner, gateway, MemoryStore());
    addTearDown(controller.dispose);
    final repo = RemindingTaskRepository(inner, controller.refresh);
    await controller.setOwner('a');
    await controller.save(enabled);
    final created = await repo.createTask(
      task('', DateTime.now().add(const Duration(days: 2))),
    );
    await controller.refresh();
    expect(gateway.scheduled, hasLength(1));
    await repo.updateTask(
      task(created.id, created.dueAt, status: TaskStatus.completed),
    );
    await controller.refresh();
    expect(gateway.scheduled, isEmpty);
    await repo.createTask(task('', created.dueAt));
    await controller.refresh();
    expect(gateway.scheduled, hasLength(1));
    await controller.save(enabled.copyWith(enabled: false));
    expect(gateway.scheduled, isEmpty);
    await controller.save(enabled);
    await repo.deleteTask((await inner.fetchTasks()).last.id);
    await controller.refresh();
    expect(gateway.scheduled, isEmpty);
    await controller.setOwner(null);
    expect(controller.available, isFalse);
    expect(controller.preferences.enabled, isFalse);
  });

  test('Notification failure does not fail a confirmed task write', () async {
    final inner = LocalTaskRepository();
    final gateway = FakeGateway();
    final controller = ReminderController(inner, gateway, MemoryStore());
    addTearDown(controller.dispose);
    await controller.setOwner('a');
    await controller.save(enabled);
    gateway.failSchedule = true;
    final repo = RemindingTaskRepository(inner, controller.refresh);
    final saved = await repo.createTask(
      task('', DateTime.now().add(const Duration(days: 2))),
    );
    await controller.refresh();
    expect(saved.id, isNotEmpty);
    expect(await inner.fetchTasks(), hasLength(1));
    expect(controller.scheduledCount, 0);
    expect(controller.message, contains('does not affect saved tasks'));
    expect(controller.message, isNot(contains('raw private')));
  });

  test(
    'Account switch during scheduling leaves no stale owner reminder',
    () async {
      final inner = LocalTaskRepository();
      await inner.createTask(
        task('', DateTime.now().add(const Duration(days: 2))),
      );
      final gateway = FakeGateway();
      final store = MemoryStore();
      final controller = ReminderController(inner, gateway, store);
      addTearDown(controller.dispose);
      await controller.setOwner('a');
      final gate = Completer<void>();
      gateway.scheduleGate = gate;
      final saving = controller.save(enabled);
      // Let the serialized operation reach the asynchronous schedule call.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final switching = controller.setOwner('b');
      gate.complete();
      await saving;
      await switching;
      expect(gateway.scheduled, isEmpty);
      expect(controller.preferences.enabled, isFalse);
      expect(store.values['b'], isNull);
    },
  );

  test(
    'Offline refresh preserves existing reminders and reports a safe warning',
    () async {
      final tasks = FailingReadTasks();
      await tasks.createTask(
        task('', DateTime.now().add(const Duration(days: 2))),
      );
      final gateway = FakeGateway();
      final controller = ReminderController(tasks, gateway, MemoryStore());
      addTearDown(controller.dispose);
      await controller.setOwner('a');
      await controller.save(enabled);
      expect(gateway.scheduled, hasLength(1));
      tasks.failRead = true;
      await controller.refresh();
      expect(gateway.scheduled, hasLength(1));
      expect(controller.scheduledCount, 1);
      expect(controller.message, contains('Try again'));
      expect(controller.message, isNot(contains('private')));
      await controller.setOwner(null);
      expect(gateway.scheduled, isEmpty);
    },
  );

  test(
    'Committed create, update and delete do not wait for reminder I/O',
    () async {
      final inner = LocalTaskRepository();
      final gate = Completer<void>();
      final repo = RemindingTaskRepository(inner, () => gate.future);
      final saved = await repo
          .createTask(task('', DateTime.now().add(const Duration(days: 2))))
          .timeout(const Duration(seconds: 1));
      final updated = await repo
          .updateTask(saved)
          .timeout(const Duration(seconds: 1));
      expect(updated.version, saved.version + 1);
      await repo.deleteTask(saved.id).timeout(const Duration(seconds: 1));
      expect(await inner.fetchTasks(), isEmpty);
      gate.complete();
    },
  );
}
