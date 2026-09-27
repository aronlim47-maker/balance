import 'package:flutter/foundation.dart';

import '../../core/utils/app_error_message.dart';
import '../../core/state/planning_day_controller.dart';
import '../../data/repositories/availability_repository.dart';
import '../../data/repositories/check_in_repository.dart';
import '../../data/repositories/movement_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../data/repositories/social_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/models/availability_block.dart';
import '../../domain/models/check_in.dart';
import '../../domain/models/movement_models.dart';
import '../../domain/models/plan_reservation.dart';
import '../../domain/models/recovery_slot.dart';
import '../../domain/models/social_event_record.dart';
import '../../domain/models/task_item.dart';
import '../../domain/usecases/daily_capacity.dart';
import '../../domain/usecases/world_status_calculator.dart';
import '../../domain/usecases/social_conflicts.dart';
import '../../data/repositories/world_history_repository.dart';

class TodayViewModel extends ChangeNotifier {
  TodayViewModel(
    this._taskRepository,
    this._availabilityRepository, [
    this._planRepository,
    this._recoveryRepository,
    this._planningDayController,
    this._checkInRepository,
    this._movementRepository,
    this._socialRepository,
    this._historyRepository,
  ]) : _selectedDay = _dateOnly(DateTime.now()) {
    _selectedDay = _planningDayController?.selectedDay ?? _selectedDay;
  }

  final TaskRepository _taskRepository;
  final AvailabilityRepository _availabilityRepository;
  final PlanRepository? _planRepository;
  final RecoveryRepository? _recoveryRepository;
  final PlanningDayController? _planningDayController;
  final CheckInRepository? _checkInRepository;
  final MovementRepository? _movementRepository;
  final SocialRepository? _socialRepository;
  final WorldHistoryRepository? _historyRepository;
  List<int?> _previousTotals = List.filled(7, null);
  String? historyNotice;
  final List<TaskItem> _tasks = [];
  final List<AvailabilityBlock> _availability = [];
  final List<PlanReservation> _reservations = [];
  final List<RecoverySlot> _recoverySlots = [];
  DateTime _selectedDay;
  bool _isLoading = false;
  int _loadVersion = 0;
  bool _hasLoaded = false;
  CheckIn? _checkIn;
  MovementSettings _movementSettings = const MovementSettings();
  ExerciseLog? _latestExercise;
  final List<ExerciseLog> _exerciseLogsForDay = [];
  List<SocialEventRecord>? _socialEvents;
  bool _noSocialCommitments = false;
  bool _isSavingSocial = false;
  bool _isSavingReview = false;
  bool _isSavingMovement = false;
  String? _errorMessage;

  DateTime get selectedDay => _selectedDay;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  CheckIn? get checkIn => _checkIn;
  bool get isSavingReview => _isSavingReview;
  bool get isSavingMovement => _isSavingMovement;
  MovementSettings get movementSettings => _movementSettings;
  List<ExerciseLog> get exerciseLogsForDay =>
      List.unmodifiable(_exerciseLogsForDay);
  ExerciseLog? get latestExercise => _latestExercise;
  List<SocialEventRecord> get socialEvents =>
      List.unmodifiable(_socialEvents ?? const <SocialEventRecord>[]);
  bool get noSocialCommitments => _noSocialCommitments;
  bool get isSavingSocial => _isSavingSocial;
  List<TaskItem> get tasksForDay =>
      _tasks.where(_belongsToSelectedDay).toList();
  List<TaskItem> get socialTasks => _tasks
      .where(
        (task) =>
            task.status == TaskStatus.planned &&
            task.loadCategory == LoadCategory.social,
      )
      .toList();
  TaskItem? get earlyReviewCandidate =>
      !DailyCapacity.sameDay(_selectedDay, DateTime.now())
      ? null
      : _tasks
            .where(
              (task) =>
                  task.status == TaskStatus.planned &&
                  DateTime(
                    task.dueAt.toLocal().year,
                    task.dueAt.toLocal().month,
                    task.dueAt.toLocal().day,
                  ).isAfter(_selectedDay),
            )
            .firstOrNull;
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

  /// Unknown dimensions stay unknown until their own evidence is available.
  WorldStatusResult get worldStatus {
    final day = _selectedDay;
    final hasAvailability = availabilityForDay.any(
      (block) => block.isAvailable,
    );
    return const WorldStatusCalculator().calculate(
      WorldStatusInput(
        localDate: day,
        windowStart: DateTime(day.year, day.month, day.day),
        previousSevenTotals: _previousTotals,
        plannedMinutes: _hasLoaded ? capacity.workMinutes : null,
        availableMinutes: hasAvailability ? capacity.availableMinutes : null,
        unfinishedTasks: _hasLoaded
            ? _tasks
                  .where((task) => task.status == TaskStatus.planned)
                  .map(
                    (task) => WorldStatusTask(
                      remainingMinutes: task.effectiveRemainingMinutes,
                      dueAt: task.dueAt.toLocal(),
                      category: task.loadCategory,
                    ),
                  )
                  .toList()
            : null,
        protectedRecoveryMinutes: _recoveryRepository == null || !_hasLoaded
            ? null
            : capacity.recoveryMinutes,
        mentalEnergy: _checkIn?.mentalEnergyLevel,
        physicalEnergy: _checkIn?.physicalEnergyLevel,
        movementTrackingEnabled: _movementSettings.trackingEnabled,
        movementTargetDays: _movementSettings.targetDays,
        targetRecoveryMinutes: _movementSettings.targetRecoveryMinutes,
        targetSocialMinutesWeek: _movementSettings.targetSocialMinutesWeek,
        lastExerciseDate: _latestExercise?.occurredAt.toLocal(),
        socialEvents: _socialEvents == null
            ? null
            : socialLoadForWeek(
                day,
                _socialEvents!,
                _tasks,
                _reservations,
                _recoverySlots,
              ),
        noSocialCommitments: _noSocialCommitments,
      ),
    );
  }

  Future<void> load() async {
    final loadingDay = _selectedDay;
    final loadVersion = ++_loadVersion;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final reviewFuture = _checkInRepository?.fetchCheckIn(loadingDay);
      final movementSettingsFuture = _movementRepository?.fetchSettings();
      final latestExerciseFuture = _movementRepository
          ?.fetchLatestExerciseBefore(
            DateTime(loadingDay.year, loadingDay.month, loadingDay.day + 1),
          );
      final exerciseDayFuture = _movementRepository?.fetchExerciseLogsForDay(
        loadingDay,
      );
      final socialFuture = _socialRepository?.fetchEventsForWeek(loadingDay);
      final noSocialFuture = _socialRepository?.fetchNoCommitmentsForWeek(
        loadingDay,
      );
      final results = await Future.wait<Object?>([
        _taskRepository.fetchTasks(),
        _availabilityRepository.fetchAvailability(),
        if (_planRepository != null) _planRepository.fetchPlanReservations(),
        if (_recoveryRepository != null)
          _recoveryRepository.fetchRecoverySlots(),
        reviewFuture ?? Future.value(),
        movementSettingsFuture ?? Future.value(),
        latestExerciseFuture ?? Future.value(),
        exerciseDayFuture ?? Future.value(),
        socialFuture ?? Future.value(),
        noSocialFuture ?? Future.value(),
      ]);
      final extra =
          2 +
          (_planRepository == null ? 0 : 1) +
          (_recoveryRepository == null ? 0 : 1);
      final review = results[extra] as CheckIn?;
      final movementSettings = results[extra + 1] as MovementSettings?;
      final latestExercise = results[extra + 2] as ExerciseLog?;
      final exerciseDay = results[extra + 3] as List<ExerciseLog>?;
      final socialEvents = results[extra + 4] as List<SocialEventRecord>?;
      final noSocialCommitments = results[extra + 5] as bool?;
      if (loadVersion != _loadVersion ||
          !DailyCapacity.sameDay(loadingDay, _selectedDay)) {
        return;
      }
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
      _checkIn = review;
      _movementSettings = movementSettings ?? const MovementSettings();
      _latestExercise = latestExercise;
      _exerciseLogsForDay
        ..clear()
        ..addAll(exerciseDay ?? const []);
      _socialEvents = socialEvents?.toList();
      _noSocialCommitments = noSocialCommitments ?? false;
      _hasLoaded = true;
      historyNotice = null;
      if (_historyRepository != null) {
        try {
          final totals = await _historyRepository.loadPreviousWeek(loadingDay);
          if (loadVersion == _loadVersion) _previousTotals = totals;
        } catch (_) {
          if (loadVersion == _loadVersion) {
            _previousTotals = List.filled(7, null);
            historyNotice = 'History is unavailable. Pull to refresh.';
          }
        }
      }
    } catch (error) {
      if (loadVersion != _loadVersion) return;
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not load today’s plan. Please try again.',
      );
    } finally {
      if (loadVersion == _loadVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void selectDay(DateTime day) {
    _selectedDay = _dateOnly(day);
    _hasLoaded = false;
    _previousTotals = List.filled(7, null);
    _checkIn = null;
    _latestExercise = null;
    _exerciseLogsForDay.clear();
    _socialEvents = null;
    _noSocialCommitments = false;
    _planningDayController?.selectDay(_selectedDay);
    notifyListeners();
    if (_checkInRepository != null ||
        _movementRepository != null ||
        _socialRepository != null) {
      load();
    }
  }

  Future<bool> setNoSocialCommitments(bool value) async {
    if (_socialRepository == null || _isSavingSocial) return false;
    final savingDay = _selectedDay;
    if (value && socialEvents.isNotEmpty) {
      _errorMessage =
          'Remove this week’s events before selecting no commitments.';
      notifyListeners();
      return false;
    }
    _isSavingSocial = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _socialRepository.saveNoCommitmentsForWeek(savingDay, value);
      await load();
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not save your social response. Please try again.',
      );
      return false;
    } finally {
      _isSavingSocial = false;
      notifyListeners();
    }
  }

  Future<bool> addSocialEvent(SocialEventRecord event) async {
    if (_socialRepository == null || _isSavingSocial) return false;
    final savingDay = _selectedDay;
    final day = event.startAt.toLocal();
    final selectedWeek = _dateOnly(_selectedDay)
        .subtract(Duration(days: _selectedDay.weekday - 1));
    final eventWeek = _dateOnly(day).subtract(Duration(days: day.weekday - 1));
    if (!DailyCapacity.sameDay(selectedWeek, eventWeek)) {
      _errorMessage = 'Choose a date in the selected week.';
      notifyListeners();
      return false;
    }
    _isSavingSocial = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_noSocialCommitments) {
        await _socialRepository.saveNoCommitmentsForWeek(savingDay, false);
      }
      await _socialRepository.createEvent(event);
      await load();
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not save the social event. Please try again.',
      );
      return false;
    } finally {
      _isSavingSocial = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSocialEvent(String id) async {
    if (_socialRepository == null || _isSavingSocial) return false;
    _isSavingSocial = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _socialRepository.deleteEvent(id);
      await load();
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not remove the social event. Please try again.',
      );
      return false;
    } finally {
      _isSavingSocial = false;
      notifyListeners();
    }
  }

  Future<bool> saveMovementSettings(MovementSettings settings) async {
    if (_movementRepository == null || _isSavingMovement) return false;
    _isSavingMovement = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _movementRepository.saveSettings(settings);
      await load();
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not save movement settings. Please try again.',
      );
      return false;
    } finally {
      _isSavingMovement = false;
      notifyListeners();
    }
  }

  Future<bool> recordExercise(ExerciseLog log) async {
    if (_movementRepository == null || _isSavingMovement) return false;
    if (!_movementSettings.trackingEnabled) {
      _errorMessage = 'Enable movement tracking before adding an exercise.';
      notifyListeners();
      return false;
    }
    if (!DailyCapacity.sameDay(log.occurredAt.toLocal(), _selectedDay)) {
      _errorMessage = 'Choose a time on the selected day.';
      notifyListeners();
      return false;
    }
    if (log.occurredAt.isAfter(DateTime.now())) {
      _errorMessage = 'Choose a time that has already passed.';
      notifyListeners();
      return false;
    }
    _isSavingMovement = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _movementRepository.createExerciseLog(log);
      await load();
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not save the exercise record. Please try again.',
      );
      return false;
    } finally {
      _isSavingMovement = false;
      notifyListeners();
    }
  }

  Future<bool> deleteExercise(String id) async {
    if (_movementRepository == null || _isSavingMovement) return false;
    _isSavingMovement = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _movementRepository.deleteExerciseLog(id);
      await load();
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not remove the exercise record. Please try again.',
      );
      return false;
    } finally {
      _isSavingMovement = false;
      notifyListeners();
    }
  }

  Future<bool> saveDailyReview(CheckIn review) async {
    if (_checkInRepository == null) return false;
    _isSavingReview = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final saved = await _checkInRepository.saveCheckIn(review);
      if (DailyCapacity.sameDay(saved.date, _selectedDay)) {
        _checkIn = saved;
      }
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not save Daily Review. Please try again.',
      );
      return false;
    } finally {
      _isSavingReview = false;
      notifyListeners();
    }
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
