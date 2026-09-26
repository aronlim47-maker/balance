import '../../domain/models/availability_block.dart';
import '../../domain/models/task_item.dart';
import 'availability_repository.dart';
import 'task_repository.dart';

class LocalTaskRepository implements TaskRepository {
  final List<TaskItem> _tasks = [];
  int _nextId = 1;

  @override
  Future<List<TaskItem>> fetchTasks() async => List.unmodifiable(_tasks);

  @override
  Future<TaskItem> createTask(TaskItem task) async {
    final created = TaskItem(
      id: 'local-task-${_nextId++}',
      title: task.title,
      estimatedMinutes: task.estimatedMinutes,
      dueAt: task.dueAt,
      flexibility: task.flexibility,
      status: task.status,
      isProtected: task.isProtected,
      isOptional: task.isOptional,
      remainingMinutes: task.remainingMinutes,
      scheduledStart: task.scheduledStart,
      scheduledEnd: task.scheduledEnd,
    );
    _tasks.add(created);
    return created;
  }

  @override
  Future<TaskItem> updateTask(TaskItem task) async {
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) throw StateError('Task not found.');
    _tasks[index] = task;
    return task;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((task) => task.id == taskId);
  }
}

class LocalAvailabilityRepository implements AvailabilityRepository {
  final List<AvailabilityBlock> _blocks = [];
  int _nextId = 1;

  @override
  Future<List<AvailabilityBlock>> fetchAvailability() async =>
      List.unmodifiable(_blocks);

  @override
  Future<AvailabilityBlock> createAvailability(AvailabilityBlock block) async {
    final created = AvailabilityBlock(
      id: 'local-availability-${_nextId++}',
      startAt: block.startAt,
      endAt: block.endAt,
      isAvailable: block.isAvailable,
      label: block.label,
    );
    _blocks.add(created);
    return created;
  }

  @override
  Future<AvailabilityBlock> updateAvailability(AvailabilityBlock block) async {
    final index = _blocks.indexWhere((item) => item.id == block.id);
    if (index == -1) throw StateError('Availability block not found.');
    _blocks[index] = block;
    return block;
  }

  @override
  Future<void> deleteAvailability(String blockId) async {
    _blocks.removeWhere((block) => block.id == blockId);
  }
}
