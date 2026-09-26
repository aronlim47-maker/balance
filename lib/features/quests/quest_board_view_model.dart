import 'package:flutter/foundation.dart';

import '../../core/utils/app_error_message.dart';
import '../../data/repositories/task_repository.dart';
import '../../domain/enums/task_flexibility.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/models/task_item.dart';

enum QuestSort { dueSoonest, dueLatest, title, remainingMost }

class QuestBoardViewModel extends ChangeNotifier {
  QuestBoardViewModel(this._repository);

  final TaskRepository _repository;
  final List<TaskItem> _tasks = [];
  String _searchQuery = '';
  TaskStatus? _statusFilter;
  TaskFlexibility? _flexibilityFilter;
  bool? _protectedFilter;
  DateTime? _startDate;
  DateTime? _endDate;
  QuestSort _sort = QuestSort.dueSoonest;

  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  String get searchQuery => _searchQuery;
  TaskStatus? get statusFilter => _statusFilter;
  TaskFlexibility? get flexibilityFilter => _flexibilityFilter;
  bool? get protectedFilter => _protectedFilter;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  QuestSort get sort => _sort;
  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _statusFilter != null ||
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
    _flexibilityFilter = null;
    _protectedFilter = null;
    _startDate = null;
    _endDate = null;
    notifyListeners();
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadTasks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _tasks
        ..clear()
        ..addAll(await _repository.fetchTasks());
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not load tasks. Please try again.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveTask(TaskItem task) async {
    _errorMessage = null;
    notifyListeners();
    try {
      final saved = task.id.isEmpty
          ? await _repository.createTask(task)
          : await _repository.updateTask(task);
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
    }
  }

  Future<bool> deleteTask(String taskId) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.deleteTask(taskId);
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
    }
  }
}
