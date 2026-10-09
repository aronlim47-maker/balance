import 'dart:async';

import '../../domain/models/task_item.dart';
import 'task_repository.dart';

/// Reminder failures must never turn a confirmed task write into a failed save.
class RemindingTaskRepository implements TaskRepository {
  RemindingTaskRepository(this.inner, this.afterMutation);
  final TaskRepository inner;
  final Future<void> Function() afterMutation;
  @override
  Future<List<TaskItem>> fetchTasks() => inner.fetchTasks();
  Future<void> _refresh() async {
    try {
      await afterMutation();
    } catch (_) {
      /* Controller exposes a safe warning. */
    }
  }

  @override
  Future<TaskItem> createTask(TaskItem task) async {
    final saved = await inner.createTask(task);
    unawaited(_refresh());
    return saved;
  }

  @override
  Future<TaskItem> updateTask(TaskItem task) async {
    final saved = await inner.updateTask(task);
    unawaited(_refresh());
    return saved;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await inner.deleteTask(taskId);
    unawaited(_refresh());
  }
}
