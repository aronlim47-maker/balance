import '../../core/state/lifecycle_notifier.dart';

import '../../core/utils/app_error_message.dart';
import '../../data/repositories/task_repository.dart';
import '../../domain/enums/task_flexibility.dart';
import '../../domain/enums/load_category.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/models/task_item.dart';

enum QuestSort { dueSoonest, dueLatest, title, remainingMost }

class QuestBoardViewModel extends LifecycleNotifier {
  QuestBoardViewModel(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TaskRepository _repository;

  /// Injectable for tests; the app always uses the device clock.
  final DateTime Function() _clock;
  final List<TaskItem> _tasks = [];
  String _searchQuery = '';
  TaskStatus? _statusFilter;
  bool _overdueOnly = false;
  LoadCategory? _categoryFilter;
  bool _uncategorizedOnly = false;
  TaskFlexibility? _flexibilityFilter;
  bool? _protectedFilter;
  DateTime? _startDate;
  DateTime? _endDate;
  QuestSort _sort = QuestSort.dueSoonest;

  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  String get searchQuery => _searchQuery;
  TaskStatus? get statusFilter => _statusFilter;
  bool get overdueOnly => _overdueOnly;
  LoadCategory? get categoryFilter => _categoryFilter;
  bool get uncategorizedOnly => _uncategorizedOnly;
  TaskFlexibility? get flexibilityFilter => _flexibilityFilter;
  bool? get protectedFilter => _protectedFilter;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  QuestSort get sort => _sort;
  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _statusFilter != null ||
      _overdueOnly ||
      _categoryFilter != null ||
      _uncategorizedOnly ||
      _flexibilityFilter != null ||
      _protectedFilter != null ||
      _startDate != null;

  /// Display only: planned work whose due time has passed. This is never
  /// saved, and an overdue task is never moved, cancelled or penalised.
  bool isOverdue(TaskItem task) => _isOverdueAt(task, _clock());

  int get overdueCount {
    final now = _clock();
    return _tasks.where((task) => _isOverdueAt(task, now)).length;
  }

  static bool _isOverdueAt(TaskItem task, DateTime now) =>
      task.status == TaskStatus.planned && task.dueAt.isBefore(now);

  List<TaskItem> get visibleTasks {
    final query = _searchQuery.toLowerCase();
    final now = _clock();
    final result = _tasks.where((task) {
      if (query.isNotEmpty && !task.title.toLowerCase().contains(query)) {
        return false;
      }
      if (_statusFilter != null && task.status != _statusFilter) return false;
      if (_overdueOnly && !_isOverdueAt(task, now)) return false;
      if (_categoryFilter != null && task.loadCategory != _categoryFilter) {
        return false;
      }
      if (_uncategorizedOnly && task.loadCategory != null) return false;
      if (_flexibilityFilter != null &&
          task.flexibility != _flexibilityFilter) {
        return false;
      }
      if (_protectedFilter != null && task.isProtected != _protectedFilter) {
        return false;
      }
      final dueDay = _dateOnly(task.dueAt.toLocal());
      if (_startDate != null && dueDay.isBefore(_startDate!)) return false;
      if (_endDate != null && dueDay.isAfter(_endDate!)) return false;
      return true;
    }).toList();
    result.sort((a, b) {
      final comparison = switch (_sort) {
        QuestSort.dueSoonest => a.dueAt.compareTo(b.dueAt),
        QuestSort.dueLatest => b.dueAt.compareTo(a.dueAt),
        QuestSort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        QuestSort.remainingMost => b.effectiveRemainingMinutes.compareTo(
          a.effectiveRemainingMinutes,
        ),
      };
      return comparison != 0 ? comparison : a.id.compareTo(b.id);
    });
    return result;
  }

  void setSearchQuery(String value) {
    _searchQuery = value.trim();
    notifyListeners();
  }

  /// [overdueOnly] shows planned tasks past their due time; it replaces any
  /// status choice because overdue tasks are always planned.
  void setStatusFilter(TaskStatus? value, {bool overdueOnly = false}) {
    _statusFilter = overdueOnly ? null : value;
    _overdueOnly = overdueOnly;
    notifyListeners();
  }

  void setCategoryFilter(
    LoadCategory? value, {
    bool uncategorizedOnly = false,
  }) {
    _categoryFilter = value;
    _uncategorizedOnly = uncategorizedOnly;
    notifyListeners();
  }

  void setFlexibilityFilter(TaskFlexibility? value) {
    _flexibilityFilter = value;
    notifyListeners();
  }

  void setProtectedFilter(bool? value) {
    _protectedFilter = value;
    notifyListeners();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    assert((start == null) == (end == null));
    _startDate = start == null ? null : _dateOnly(start);
    _endDate = end == null ? null : _dateOnly(end);
    notifyListeners();
  }

  void setSort(QuestSort value) {
    _sort = value;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _statusFilter = null;
    _overdueOnly = false;
    _categoryFilter = null;
    _uncategorizedOnly = false;
    _flexibilityFilter = null;
    _protectedFilter = null;
    _startDate = null;
    _endDate = null;
    notifyListeners();
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isLoading = false;
  int _loadVersion = 0;
  bool _isSaving = false;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  String? _loadErrorMessage;
  String? get loadErrorMessage => _loadErrorMessage;

  Future<void> loadTasks() async {
    if (isDisposed || _isSaving) return;
    final version = ++_loadVersion;
    _isLoading = true;
    _errorMessage = null;
    _loadErrorMessage = null;
    notifyListeners();
    try {
      final tasks = await _repository.fetchTasks();
      if (isDisposed || version != _loadVersion) return;
      _tasks
        ..clear()
        ..addAll(tasks);
    } catch (error) {
      if (isDisposed || version != _loadVersion) return;
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not load tasks. Please try again.',
      );
      _loadErrorMessage = _errorMessage;
    } finally {
      if (!isDisposed && version == _loadVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> saveTask(TaskItem task) async {
    if (isDisposed || _isSaving) return false;
    _isSaving = true;
    ++_loadVersion;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
    try {
      final saved = task.id.isEmpty
          ? await _repository.createTask(task)
          : await _repository.updateTask(task);
      if (isDisposed) return true;
      final index = _tasks.indexWhere((item) => item.id == saved.id);
      if (index == -1) {
        _tasks.add(saved);
      } else {
        _tasks[index] = saved;
      }
      _tasks.sort((a, b) => a.dueAt.compareTo(b.dueAt));
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not save this task. Please try again.',
      );
      notifyListeners();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Marks a task done (completed) or not done (planned) in one tap.
  /// Only the status changes: time, deadline, category, protection and
  /// version checks stay exactly as in a normal edit.
  Future<bool> setTaskStatus(TaskItem task, TaskStatus status) async {
    if (task.status == status) return true;
    return saveTask(
      TaskItem(
        id: task.id,
        title: task.title,
        estimatedMinutes: task.estimatedMinutes,
        dueAt: task.dueAt,
        flexibility: task.flexibility,
        status: status,
        isProtected: task.isProtected,
        protectedCommitmentType: task.protectedCommitmentType,
        isOptional: task.isOptional,
        loadCategory: task.loadCategory,
        remainingMinutes: task.remainingMinutes,
        scheduledStart: task.scheduledStart,
        scheduledEnd: task.scheduledEnd,
        version: task.version,
      ),
    );
  }

  Future<bool> deleteTask(String taskId) async {
    if (isDisposed || _isSaving) return false;
    _isSaving = true;
    ++_loadVersion;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.deleteTask(taskId);
      if (isDisposed) return true;
      _tasks.removeWhere((task) => task.id == taskId);
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not delete this task. Please try again.',
      );
      notifyListeners();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    ++_loadVersion;
    super.dispose();
  }
}
