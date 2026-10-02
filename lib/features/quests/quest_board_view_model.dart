import '../../core/state/lifecycle_notifier.dart';

import '../../core/utils/app_error_message.dart';
import '../../data/repositories/task_repository.dart';
import '../../domain/enums/task_flexibility.dart';
import '../../domain/enums/load_category.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/models/task_item.dart';

enum QuestSort { dueSoonest, dueLatest, title, remainingMost }

class QuestBoardViewModel extends LifecycleNotifier {
  QuestBoardViewModel(this._repository);

  final TaskRepository _repository;
  final List<TaskItem> _tasks = [];
  String _searchQuery = '';
  TaskStatus? _statusFilter;
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
      _categoryFilter != null ||
      _uncategorizedOnly ||
      _flexibilityFilter != null ||
      _protectedFilter != null ||
      _startDate != null;

  List<TaskItem> get visibleTasks {
    final query = _searchQuery.toLowerCase();
    final result = _tasks.where((task) {
      if (query.isNotEmpty && !task.title.toLowerCase().contains(query)) {
        return false;
      }
      if (_statusFilter != null && task.status != _statusFilter) return false;
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

  void setStatusFilter(TaskStatus? value) {
    _statusFilter = value;
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

  Future<void> loadTasks() async {
    if (isDisposed || _isSaving) return;
    final version = ++_loadVersion;
    _isLoading = true;
    _errorMessage = null;
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
