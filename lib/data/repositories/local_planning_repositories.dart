import '../../domain/models/availability_block.dart';
import '../../domain/models/task_item.dart';
import '../../domain/models/check_in.dart';
import '../../domain/models/movement_models.dart';
import '../../domain/models/social_event_record.dart';
import 'availability_repository.dart';
import 'check_in_repository.dart';
import 'movement_repository.dart';
import 'social_repository.dart';
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
      protectedCommitmentType: task.protectedCommitmentType,
      isOptional: task.isOptional,
      loadCategory: task.loadCategory,
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
    if (_tasks[index].version != task.version) {
      throw StateError('Task edit conflict: refresh before editing again.');
    }
    final saved = task.withVersion(task.version + 1);
    _tasks[index] = saved;
    return saved;
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

class LocalCheckInRepository implements CheckInRepository {
  final List<CheckIn> _checkIns = [];

  @override
  Future<List<CheckIn>> fetchCheckIns() async => List.unmodifiable(_checkIns);

  @override
  Future<CheckIn?> fetchCheckIn(DateTime date) async {
    for (final checkIn in _checkIns) {
      if (_sameDay(checkIn.date, date)) return checkIn;
    }
    return null;
  }

  @override
  Future<CheckIn> saveCheckIn(CheckIn checkIn) async {
    _checkIns.removeWhere((item) => _sameDay(item.date, checkIn.date));
    _checkIns.add(checkIn);
    return checkIn;
  }

  @override
  Future<void> deleteCheckIn(DateTime date) async {
    _checkIns.removeWhere((item) => _sameDay(item.date, date));
  }

  static bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class LocalMovementRepository implements MovementRepository {
  MovementSettings _settings = const MovementSettings();
  final List<ExerciseLog> _logs = [];
  int _nextId = 1;

  @override
  Future<MovementSettings> fetchSettings() async => _settings;

  @override
  Future<MovementSettings> saveSettings(MovementSettings settings) async {
    _settings = settings;
    return settings;
  }

  @override
  Future<ExerciseLog?> fetchLatestExerciseBefore(DateTime endExclusive) async {
    final matches =
        _logs.where((log) => log.occurredAt.isBefore(endExclusive)).toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<List<ExerciseLog>> fetchExerciseLogsForDay(DateTime day) async {
    final matches = _logs.where((log) {
      final local = log.occurredAt.toLocal();
      return local.year == day.year &&
          local.month == day.month &&
          local.day == day.day;
    }).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return List.unmodifiable(matches);
  }

  @override
  Future<ExerciseLog> createExerciseLog(ExerciseLog log) async {
    final saved = ExerciseLog(
      id: 'local-exercise-${_nextId++}',
      occurredAt: log.occurredAt,
      durationMinutes: log.durationMinutes,
      taskId: log.taskId,
      intensity: log.intensity,
    );
    _logs.add(saved);
    return saved;
  }

  @override
  Future<void> deleteExerciseLog(String id) async {
    _logs.removeWhere((log) => log.id == id);
  }
}

class LocalSocialRepository implements SocialRepository {
  final List<SocialEventRecord> events = [];
  final Map<DateTime, bool> _weekResponses = {};
  int _nextId = 1;

  @override
  Future<List<SocialEventRecord>> fetchEventsForWeek(DateTime day) async {
    final start = _weekStart(day);
    final end = start.add(const Duration(days: 7));
    return List.unmodifiable(
      events.where((event) {
        return event.endAt.isAfter(start) && event.startAt.isBefore(end);
      }),
    );
  }

  @override
  Future<bool> fetchNoCommitmentsForWeek(DateTime day) async =>
      _weekResponses[_weekStart(day)] ?? false;

  @override
  Future<void> saveNoCommitmentsForWeek(DateTime day, bool value) async {
    _weekResponses[_weekStart(day)] = value;
  }

  @override
  Future<SocialEventRecord> createEvent(SocialEventRecord event) async {
    final saved = SocialEventRecord(
      id: 'local-social-${_nextId++}',
      taskId: event.taskId,
      startAt: event.startAt,
      endAt: event.endAt,
      pressure: event.pressure,
    );
    events.add(saved);
    _weekResponses[_weekStart(event.startAt.toLocal())] = false;
    return saved;
  }

  @override
  Future<void> deleteEvent(String id) async {
    events.removeWhere((event) => event.id == id);
  }

  static DateTime _weekStart(DateTime day) {
    final local = DateTime(day.year, day.month, day.day);
    return local.subtract(Duration(days: local.weekday - 1));
  }
}
