// Quest Board: one-tap Mark as done / not done, display-only Overdue label,
// Overdue filter and the Finished group. Also covers the WS12 rule that
// skipping the exercise prompt records nothing.
import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/movement_repository.dart';
import 'package:balance/data/repositories/task_repository.dart';
import 'package:balance/domain/enums/load_category.dart';
import 'package:balance/domain/enums/task_status.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/features/auth/auth_view_model.dart';
import 'package:balance/features/quests/quest_board_screen.dart';
import 'package:balance/features/quests/quest_board_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('QuestBoardViewModel status and overdue', () {
    final now = DateTime(2026, 10, 9, 12);

    test('overdue is planned work past its due time, never saved', () async {
      final repository = _FakeTaskRepository([
        _task('late', 'Revision of Finals!', DateTime(2026, 10, 3, 16, 32)),
        _task('soon', 'Lab report', DateTime(2026, 10, 10, 9)),
        _task(
          'done',
          'Old essay',
          DateTime(2026, 10, 1),
          status: TaskStatus.completed,
        ),
      ]);
      final viewModel = QuestBoardViewModel(repository, clock: () => now);
      await viewModel.loadTasks();

      expect(viewModel.isOverdue(viewModel.tasks[0]), isTrue);
      expect(
        viewModel.tasks.where(viewModel.isOverdue).map((task) => task.id),
        ['late'],
      );
      expect(viewModel.overdueCount, 1);
      expect(repository.updates, 0);
      expect(
        repository.stored('late').dueAt,
        DateTime(2026, 10, 3, 16, 32),
      );
      expect(repository.stored('late').status, TaskStatus.planned);
    });

    test('Overdue filter shows only overdue tasks and clears', () async {
      final viewModel = QuestBoardViewModel(
        _FakeTaskRepository([
          _task('late', 'Revision of Finals!', DateTime(2026, 10, 3)),
          _task('soon', 'Lab report', DateTime(2026, 10, 10)),
        ]),
        clock: () => now,
      );
      await viewModel.loadTasks();

      viewModel.setStatusFilter(null, overdueOnly: true);
      expect(viewModel.overdueOnly, isTrue);
      expect(viewModel.statusFilter, isNull);
      expect(viewModel.hasActiveFilters, isTrue);
      expect(viewModel.visibleTasks.single.id, 'late');

      viewModel.setStatusFilter(TaskStatus.planned);
      expect(viewModel.overdueOnly, isFalse);
      expect(viewModel.visibleTasks, hasLength(2));

      viewModel.setStatusFilter(null, overdueOnly: true);
      viewModel.clearFilters();
      expect(viewModel.overdueOnly, isFalse);
      expect(viewModel.hasActiveFilters, isFalse);
    });

    test('Mark as done changes only the status and can be undone', () async {
      final original = TaskItem(
        id: 'essay',
        title: 'Essay',
        estimatedMinutes: 90,
        remainingMinutes: 60,
        dueAt: DateTime(2026, 10, 3),
        isProtected: true,
        loadCategory: LoadCategory.study,
        version: 4,
      );
      final repository = _FakeTaskRepository([original]);
      final viewModel = QuestBoardViewModel(repository, clock: () => now);
      await viewModel.loadTasks();

      expect(
        await viewModel.setTaskStatus(
          viewModel.tasks.single,
          TaskStatus.completed,
        ),
        isTrue,
      );
      final done = repository.stored('essay');
      expect(done.status, TaskStatus.completed);
      expect(done.title, 'Essay');
      expect(done.dueAt, original.dueAt);
      expect(done.remainingMinutes, 60);
      expect(done.isProtected, isTrue);
      expect(done.loadCategory, LoadCategory.study);
      expect(repository.lastUpdateVersion, 4);
      expect(viewModel.overdueCount, 0);

      expect(
        await viewModel.setTaskStatus(
          viewModel.tasks.single,
          TaskStatus.planned,
        ),
        isTrue,
      );
      expect(repository.stored('essay').status, TaskStatus.planned);
      expect(viewModel.overdueCount, 1);
    });

    test('a failed status change reports a safe message', () async {
      final repository = _FakeTaskRepository([
        _task('essay', 'Essay', DateTime(2026, 10, 3)),
      ]);
      final viewModel = QuestBoardViewModel(repository, clock: () => now);
      await viewModel.loadTasks();
      repository.failUpdates = true;

      expect(
        await viewModel.setTaskStatus(
          viewModel.tasks.single,
          TaskStatus.completed,
        ),
        isFalse,
      );
      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.errorMessage, isNot(contains('Simulated')));
      expect(viewModel.tasks.single.status, TaskStatus.planned);
    });
  });

  group('Quest Board screen', () {
    Future<void> pumpBoard(
      WidgetTester tester,
      _FakeTaskRepository repository, {
      MovementRepository? movement,
    }) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthViewModel()),
            Provider<TaskRepository>.value(value: repository),
            if (movement != null)
              Provider<MovementRepository>.value(value: movement),
          ],
          child: const MaterialApp(home: QuestBoardScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the practical name, overdue label and count', (
      tester,
    ) async {
      final today = DateTime.now();
      await pumpBoard(
        tester,
        _FakeTaskRepository([
          _task(
            'late',
            'Revision of Finals!',
            today.subtract(const Duration(days: 2)),
          ),
          _task('soon', 'Lab report', today.add(const Duration(days: 2))),
        ]),
      );

      expect(find.text('TASKS'), findsOneWidget);
      expect(find.text('QUEST BOARD'), findsOneWidget);
      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.textContaining('1 overdue'), findsOneWidget);
      expect(find.textContaining('Was due'), findsOneWidget);
    });

    testWidgets('Mark as done moves the task to Finished and back', (
      tester,
    ) async {
      final today = DateTime.now();
      final repository = _FakeTaskRepository([
        _task(
          'late',
          'Revision of Finals!',
          today.subtract(const Duration(days: 2)),
        ),
      ]);
      await pumpBoard(tester, repository);
      expect(find.text('FINISHED'), findsNothing);

      await tester.tap(find.byTooltip('Task actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as done'));
      await tester.pumpAndSettle();

      expect(repository.stored('late').status, TaskStatus.completed);
      expect(find.text('Marked as done.'), findsOneWidget);
      expect(find.text('FINISHED'), findsOneWidget);
      expect(find.text('OVERDUE'), findsNothing);

      await tester.tap(find.byTooltip('Task actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as not done'));
      await tester.pumpAndSettle();

      expect(repository.stored('late').status, TaskStatus.planned);
      expect(find.text('FINISHED'), findsNothing);
      expect(find.text('OVERDUE'), findsOneWidget);
    });

    testWidgets('Status filter offers Overdue', (tester) async {
      final today = DateTime.now();
      await pumpBoard(
        tester,
        _FakeTaskRepository([
          _task(
            'late',
            'Revision of Finals!',
            today.subtract(const Duration(days: 2)),
          ),
          _task('soon', 'Lab report', today.add(const Duration(days: 2))),
        ]),
      );

      await tester.tap(find.text('Status: All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overdue').last);
      await tester.pumpAndSettle();

      expect(find.text('Status: Overdue'), findsOneWidget);
      expect(find.text('Revision of Finals!'), findsOneWidget);
      expect(find.text('Lab report'), findsNothing);
    });

    testWidgets('completing an Exercise task offers a prompt; Skip records '
        'nothing', (tester) async {
      final movement = LocalMovementRepository();
      final repository = _FakeTaskRepository([
        _task(
          'walk',
          'Evening walk',
          DateTime.now().add(const Duration(days: 1)),
          category: LoadCategory.exercise,
        ),
      ]);
      await pumpBoard(tester, repository, movement: movement);

      await tester.tap(find.byTooltip('Task actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as done'));
      await tester.pumpAndSettle();

      expect(find.text('Record this exercise?'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(repository.stored('walk').status, TaskStatus.completed);
      expect(
        await movement.fetchLatestExerciseBefore(
          DateTime.now().add(const Duration(days: 30)),
        ),
        isNull,
      );
    });
  });
}

TaskItem _task(
  String id,
  String title,
  DateTime dueAt, {
  TaskStatus status = TaskStatus.planned,
  LoadCategory category = LoadCategory.study,
}) => TaskItem(
  id: id,
  title: title,
  estimatedMinutes: 60,
  dueAt: dueAt,
  status: status,
  loadCategory: category,
);

class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository(Iterable<TaskItem> seed) : _tasks = List.of(seed);

  final List<TaskItem> _tasks;
  bool failUpdates = false;
  int updates = 0;
  int? lastUpdateVersion;

  TaskItem stored(String id) => _tasks.firstWhere((task) => task.id == id);

  @override
  Future<List<TaskItem>> fetchTasks() async => List.of(_tasks);

  @override
  Future<TaskItem> createTask(TaskItem task) async {
    _tasks.add(task);
    return task;
  }

  @override
  Future<TaskItem> updateTask(TaskItem task) async {
    if (failUpdates) throw StateError('Simulated update failure');
    updates++;
    lastUpdateVersion = task.version;
    final index = _tasks.indexWhere((item) => item.id == task.id);
    final saved = task.withVersion(task.version + 1);
    _tasks[index] = saved;
    return saved;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((task) => task.id == taskId);
  }
}
