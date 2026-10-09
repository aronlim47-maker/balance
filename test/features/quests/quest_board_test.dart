import 'package:balance/data/repositories/task_repository.dart';
import 'package:balance/domain/enums/task_flexibility.dart';
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
  group('QuestBoardViewModel', () {
    test('loads, creates, updates and deletes tasks', () async {
      final repository = _FakeTaskRepository([
        _task('task-1', 'Existing task'),
      ]);
      final viewModel = QuestBoardViewModel(repository);

      await viewModel.loadTasks();
      expect(viewModel.tasks.single.title, 'Existing task');

      await viewModel.saveTask(_task('', 'New task'));
      expect(viewModel.tasks, hasLength(2));

      final created = viewModel.tasks.firstWhere(
        (task) => task.title == 'New task',
      );
      await viewModel.saveTask(_task(created.id, 'Updated task'));
      expect(
        viewModel.tasks.any((task) => task.title == 'Updated task'),
        isTrue,
      );

      await viewModel.deleteTask(created.id);
      expect(viewModel.tasks, hasLength(1));
    });

    test('exposes repository errors', () async {
      final viewModel = QuestBoardViewModel(
        _FakeTaskRepository([], fail: true),
      );

      await viewModel.loadTasks();

      expect(viewModel.errorMessage, 'Could not load tasks. Please try again.');
      expect(viewModel.loadErrorMessage, viewModel.errorMessage);
      expect(viewModel.isLoading, isFalse);
    });

    test(
      'searches, filters and sorts tasks without changing the source',
      () async {
        final viewModel = QuestBoardViewModel(
          _FakeTaskRepository([
            TaskItem(
              id: 'math',
              title: 'Math assignment',
              estimatedMinutes: 120,
              remainingMinutes: 90,
              dueAt: DateTime(2026, 10, 2, 18),
              flexibility: TaskFlexibility.fixed,
              isProtected: true,
              loadCategory: LoadCategory.study,
            ),
            TaskItem(
              id: 'lab',
              title: 'Database lab',
              estimatedMinutes: 60,
              dueAt: DateTime(2026, 10, 1, 12),
              loadCategory: LoadCategory.errand,
            ),
            TaskItem(
              id: 'reading',
              title: 'Reading',
              estimatedMinutes: 30,
              dueAt: DateTime(2026, 10, 3, 21),
              status: TaskStatus.completed,
            ),
          ]),
        );
        await viewModel.loadTasks();

        expect(viewModel.visibleTasks.map((task) => task.id), [
          'lab',
          'math',
          'reading',
        ]);
        viewModel.setSearchQuery('MATH');
        expect(viewModel.visibleTasks.single.id, 'math');
        viewModel.setCategoryFilter(LoadCategory.study);
        expect(viewModel.visibleTasks.single.id, 'math');
        viewModel.setCategoryFilter(LoadCategory.social);
        expect(viewModel.visibleTasks, isEmpty);
        viewModel.clearFilters();
        viewModel.setCategoryFilter(null, uncategorizedOnly: true);
        expect(viewModel.visibleTasks.single.id, 'reading');
        expect(viewModel.hasActiveFilters, isTrue);
        viewModel.clearFilters();
        viewModel.setStatusFilter(TaskStatus.completed);
        expect(viewModel.visibleTasks.single.id, 'reading');
        viewModel.clearFilters();
        viewModel.setFlexibilityFilter(TaskFlexibility.fixed);
        viewModel.setProtectedFilter(true);
        viewModel.setDateRange(DateTime(2026, 10, 2), DateTime(2026, 10, 2));
        expect(viewModel.visibleTasks.single.id, 'math');
        viewModel.setDateRange(DateTime(2026, 10, 3), DateTime(2026, 10, 3));
        expect(viewModel.visibleTasks, isEmpty);

        viewModel.clearFilters();
        viewModel.setSort(QuestSort.remainingMost);
        expect(viewModel.visibleTasks.map((task) => task.id), [
          'math',
          'lab',
          'reading',
        ]);
        viewModel.setSort(QuestSort.dueLatest);
        expect(viewModel.visibleTasks.first.id, 'reading');
        expect(viewModel.tasks, hasLength(3));
      },
    );
  });

  testWidgets('shows the empty Quest Board state', (tester) async {
    final repository = _FakeTaskRepository([]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthViewModel()),
          Provider<TaskRepository>.value(value: repository),
        ],
        child: const MaterialApp(home: QuestBoardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The page eyebrow is shown in capitals in the RPG header.
    expect(find.text('QUEST BOARD'), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('Create task'), findsOneWidget);
  });

  testWidgets('search bar filters visible Quest Board cards', (tester) async {
    final repository = _FakeTaskRepository([
      _task('math', 'Math assignment'),
      _task('lab', 'Database lab'),
    ]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthViewModel()),
          Provider<TaskRepository>.value(value: repository),
        ],
        child: const MaterialApp(home: QuestBoardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Math assignment'), findsOneWidget);
    expect(find.text('Database lab'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'database');
    await tester.pumpAndSettle();
    expect(find.text('Math assignment'), findsNothing);
    expect(find.text('Database lab'), findsOneWidget);
  });

  testWidgets('refresh failure keeps tasks visible and offers retry', (
    tester,
  ) async {
    final repository = _FakeTaskRepository([_task('math', 'Math assignment')]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthViewModel()),
          Provider<TaskRepository>.value(value: repository),
        ],
        child: const MaterialApp(home: QuestBoardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    repository.fail = true;
    await tester.drag(find.byType(ListView).last, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('Math assignment'), findsOneWidget);
    expect(
      find.text('Could not load tasks. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Math assignment'), findsOneWidget);
    expect(find.text('Could not load tasks. Please try again.'), findsNothing);
  });

  testWidgets('category menu filters Quest Board cards', (tester) async {
    final repository = _FakeTaskRepository([
      TaskItem(
        id: 'study',
        title: 'Study report',
        estimatedMinutes: 60,
        dueAt: DateTime(2026, 10, 1),
        loadCategory: LoadCategory.study,
      ),
      TaskItem(
        id: 'exercise',
        title: 'Evening walk',
        estimatedMinutes: 30,
        dueAt: DateTime(2026, 10, 2),
        loadCategory: LoadCategory.exercise,
      ),
    ]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthViewModel()),
          Provider<TaskRepository>.value(value: repository),
        ],
        child: const MaterialApp(home: QuestBoardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category: All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercise').last);
    await tester.pumpAndSettle();
    expect(find.text('Evening walk'), findsOneWidget);
    expect(find.text('Study report'), findsNothing);
    expect(find.text('Clear filters'), findsOneWidget);
  });
}

TaskItem _task(String id, String title) => TaskItem(
  id: id,
  title: title,
  estimatedMinutes: 60,
  dueAt: DateTime.utc(2026, 10),
);

class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository(Iterable<TaskItem> seed, {this.fail = false})
    : _tasks = List.of(seed);

  final List<TaskItem> _tasks;
  bool fail;
  int _nextId = 2;

  @override
  Future<List<TaskItem>> fetchTasks() async {
    if (fail) throw Exception('Database unavailable');
    return List.of(_tasks);
  }

  @override
  Future<TaskItem> createTask(TaskItem task) async {
    final created = TaskItem(
      id: 'task-${_nextId++}',
      title: task.title,
      estimatedMinutes: task.estimatedMinutes,
      dueAt: task.dueAt,
      flexibility: task.flexibility,
      status: task.status,
      isProtected: task.isProtected,
      isOptional: task.isOptional,
    );
    _tasks.add(created);
    return created;
  }

  @override
  Future<TaskItem> updateTask(TaskItem task) async {
    final index = _tasks.indexWhere((item) => item.id == task.id);
    _tasks[index] = task;
    return task;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((task) => task.id == taskId);
  }
}
