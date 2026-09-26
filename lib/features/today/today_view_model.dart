import 'package:flutter/foundation.dart';

import '../../core/utils/app_error_message.dart';
import '../../core/state/planning_day_controller.dart';
import '../../data/repositories/availability_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/models/availability_block.dart';
import '../../domain/models/plan_reservation.dart';
import '../../domain/models/recovery_slot.dart';
import '../../domain/models/task_item.dart';
import '../../domain/usecases/daily_capacity.dart';

class TodayViewModel extends ChangeNotifier {
  TodayViewModel(
    this._taskRepository,
    this._availabilityRepository, [
    this._planRepository,
    this._recoveryRepository,
    this._planningDayController,
  ]) : _selectedDay = _dateOnly(DateTime.now()) {
    _selectedDay = _planningDayController?.selectedDay ?? _selectedDay;
  }

  final TaskRepository _taskRepository;
  final AvailabilityRepository _availabilityRepository;
  final PlanRepository? _planRepository;
  final RecoveryRepository? _recoveryRepository;
  final PlanningDayController? _planningDayController;
  final List<TaskItem> _tasks = [];
  final List<AvailabilityBlock> _availability = [];
  final List<PlanReservation> _reservations = [];
  final List<RecoverySlot> _recoverySlots = [];
  DateTime _selectedDay;
  bool _isLoading = false;
  String? _errorMessage;

  DateTime get selectedDay => _selectedDay;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<TaskItem> get tasksForDay =>
      _tasks.where(_belongsToSelectedDay).toList();
  List<AvailabilityBlock> get availabilityForDay =>
      _availability.where(_overlapsSelectedDay).toList();

  DailyCapacity get capacity => DailyCapacity.forDay(
    day: _selectedDay,
    tasks: _tasks,
    availability: _availability,
    reservations: _reservations,
    recoverySlots: _recoverySlots,
  );

  int get availableMinutes => capacity.availableMinutes;
  int get plannedMinutes => capacity.plannedMinutes;
  int get overloadMinutes => capacity.overloadMinutes;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _taskRepository.fetchTasks(),
        _availabilityRepository.fetchAvailability(),
        if (_planRepository != null) _planRepository.fetchPlanReservations(),
        if (_recoveryRepository != null)
          _recoveryRepository.fetchRecoverySlots(),
      ]);
      _tasks
        ..clear()
        ..addAll(results[0] as List<TaskItem>);
      _availability
        ..clear()
        ..addAll(results[1] as List<AvailabilityBlock>);
      _reservations
        ..clear()
        ..addAll(
          _planRepository == null
              ? const []
              : results[2] as List<PlanReservation>,
        );
      _recoverySlots
        ..clear()
        ..addAll(
          _recoveryRepository == null
              ? const []
              : results[_planRepository == null ? 2 : 3] as List<RecoverySlot>,
        );
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not load today’s plan. Please try again.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectDay(DateTime day) {
    _selectedDay = _dateOnly(day);
    _planningDayController?.selectDay(_selectedDay);
    notifyListeners();
  }

  Future<bool> saveAvailability(AvailabilityBlock block) async {
    _errorMessage = null;
    notifyListeners();
    try {
      final saved = block.id.isEmpty
          ? await _availabilityRepository.createAvailability(block)
          : await _availabilityRepository.updateAvailability(block);
      final index = _availability.indexWhere((item) => item.id == saved.id);
      if (index == -1) {
        _availability.add(saved);
      } else {
        _availability[index] = saved;
      }
      _availability.sort((a, b) => a.startAt.compareTo(b.startAt));
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not save this time block. Please try again.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAvailability(String blockId) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await _availabilityRepository.deleteAvailability(blockId);
      _availability.removeWhere((block) => block.id == blockId);
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not delete this time block. Please try again.',
      );
      notifyListeners();
      return false;
    }
  }

  bool _belongsToSelectedDay(TaskItem task) {
    if (task.status != TaskStatus.planned) return false;
    if (task.scheduledStart != null && task.scheduledEnd != null) {
      return DailyCapacity.overlapsDay(
        task.scheduledStart!,
        task.scheduledEnd!,
        _selectedDay,
      );
    }
    return DailyCapacity.sameDay(task.dueAt.toLocal(), _selectedDay);
  }

  bool _overlapsSelectedDay(AvailabilityBlock block) =>
      DailyCapacity.overlapsDay(block.startAt, block.endAt, _selectedDay);

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
