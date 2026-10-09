import '../../core/state/lifecycle_notifier.dart';

import '../../core/utils/app_error_message.dart';
import '../../core/utils/calendar_week.dart';
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

class TodayViewModel extends LifecycleNotifier {
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
  WorldStatusResult? _historicalStatus;
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
  bool _isSavingAvailability = false;
  bool _isSavingMovement = false;
  String? _errorMessage;
  String? _loadErrorMessage;
  String? _refreshWarning;

  DateTime get selectedDay => _selectedDay;

  /// Recorded World Status totals for the seven dates before [selectedDay],
  /// oldest first; `null` means no snapshot exists for that date.
  List<int?> get previousTotals => List.unmodifiable(_previousTotals);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  String? get loadErrorMessage => _loadErrorMessage;
  String? get refreshWarning => _refreshWarning;
  List<TaskItem> get allTasks => List.unmodifiable(_tasks);
  List<AvailabilityBlock> get allAvailability =>
      List.unmodifiable(_availability);
  List<PlanReservation> get allReservations => List.unmodifiable(_reservations);
  List<RecoverySlot> get allRecoverySlots => List.unmodifiable(_recoverySlots);
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

  /// Exercise tasks that an exercise record may be linked to.
  /// Cancelled tasks are excluded; the user still confirms the real time
  /// and duration, so nothing is logged automatically.
  List<TaskItem> get exerciseTasks => _tasks
      .where(
        (task) =>
            task.status != TaskStatus.cancelled &&
            task.loadCategory == LoadCategory.exercise,
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
    if (day.isBefore(_dateOnly(DateTime.now()))) {
      return _historicalStatus ??
          WorldStatusResult(
            dimensions: {
              for (final dimension in WorldDimension.values)
                dimension: const DimensionResult.unknown(
                  'No snapshot was recorded for this day.',
                ),
            },
            totalScore: null,
            coverage: 0,
            isPartial: false,
            trend: WorldTrend.notEnoughHistory,
          );
    }
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
                      id: task.id,
                      title: task.title,
                      remainingMinutes: task.effectiveRemainingMinutes,
                      dueAt: task.dueAt.toLocal(),
                      category: task.loadCategory,
                      scheduledStart: task.scheduledStart?.toLocal(),
                    ),
                  )
                  .toList()
            : null,
        protectedRecoveryMinutes: _recoveryRepository == null || !_hasLoaded
            ? null
            : capacity.recoveryMinutes,
        protectedRecoverySources: _recoverySlots
            .where((slot) {
              final start = DateTime(day.year, day.month, day.day);
              final end = DateTime(day.year, day.month, day.day + 1);
              return slot.isProtected &&
                  slot.startAt.isBefore(end) &&
                  slot.endAt.isAfter(start);
            })
            .map((slot) {
              final activity = slot.selectedActivity?.trim();
              final date = slot.startAt.toLocal();
              final dateLabel =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-'
                  '${date.day.toString().padLeft(2, '0')}';
              return activity == null || activity.isEmpty
                  ? 'Protected recovery · $dateLabel'
                  : '$activity · $dateLabel';
            })
            .toList(growable: false),
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
    if (isDisposed || _isSavingReview || _isSavingAvailability) return;
    final loadingDay = _selectedDay;
    final loadVersion = ++_loadVersion;
    _isLoading = true;
    _errorMessage = null;
    _loadErrorMessage = null;
    _refreshWarning = null;
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
      if (isDisposed ||
          loadVersion != _loadVersion ||
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
      _historicalStatus = null;
      if (loadingDay.isBefore(_dateOnly(DateTime.now()))) {
        try {
          final snapshot = await _historyRepository?.loadDaySnapshot(
            loadingDay,
          );
          if (loadVersion == _loadVersion) {
            _historicalStatus = snapshot;
            historyNotice = snapshot == null
                ? 'No workload record for this day.'
                : 'Recorded workload. The schedule below shows current task data.';
          }
        } catch (_) {
          if (loadVersion == _loadVersion) {
            historyNotice =
                'Recorded workload is unavailable. Pull to refresh.';
          }
        }
      }
      if (_historyRepository != null) {
        try {
          final totals = await _historyRepository.loadPreviousWeek(loadingDay);
          if (loadVersion == _loadVersion) {
            _previousTotals = totals;
            final history = _historyRepository;
            if (history is SnapshotCaptureStatus) {
              historyNotice ??=
                  (history as SnapshotCaptureStatus).captureNotice;
            }
          }
        } catch (_) {
          if (loadVersion == _loadVersion) {
            _previousTotals = List.filled(7, null);
            historyNotice ??= 'History is unavailable. Pull to refresh.';
          }
        }
      }
    } catch (error) {
      if (loadVersion != _loadVersion) return;
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not load today’s plan. Please try again.',
      );
      _loadErrorMessage = _errorMessage;
    } finally {
      if (loadVersion == _loadVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void selectDay(DateTime day, {bool reload = true}) {
    if (isDisposed) return;
    _selectedDay = _dateOnly(day);
    _hasLoaded = false;
    _previousTotals = List.filled(7, null);
    _historicalStatus = null;
    _checkIn = null;
    _latestExercise = null;
    _exerciseLogsForDay.clear();
    _socialEvents = null;
    _noSocialCommitments = false;
    _planningDayController?.selectDay(_selectedDay);
    notifyListeners();
    if (reload &&
        (_checkInRepository != null ||
            _movementRepository != null ||
            _socialRepository != null)) {
      load();
    }
  }

  void _recordRefreshWarningIfNeeded() {
    if (_errorMessage != null) {
      _refreshWarning = 'Your change was saved, but the latest view could not be loaded. Pull to refresh.';
      notifyListeners();
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
      _recordRefreshWarningIfNeeded();
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
    final day = event.startAt.toLocal();
    final selectedWeek = CalendarWeek.start(_selectedDay);
    final eventWeek = CalendarWeek.start(day);
    if (!DailyCapacity.sameDay(selectedWeek, eventWeek)) {
      _errorMessage = 'Choose a date in the selected week.';
      notifyListeners();
      return false;
    }
    _isSavingSocial = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _socialRepository.createEvent(event);
      await load();
      _recordRefreshWarningIfNeeded();
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
      _recordRefreshWarningIfNeeded();
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
      _recordRefreshWarningIfNeeded();
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
      _recordRefreshWarningIfNeeded();
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
      _recordRefreshWarningIfNeeded();
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
    if (isDisposed || _checkInRepository == null || _isSavingReview) {
      return false;
    }
    _invalidateLoads();
    _isSavingReview = true;
    _errorMessage = null;
    _refreshWarning = null;
    notifyListeners();
    try {
      final saved = await _checkInRepository.saveCheckIn(review);
      if (isDisposed) return true;
      if (DailyCapacity.sameDay(saved.date, _selectedDay)) {
        _checkIn = saved;
      }
      await _refreshHistoryAfterSave();
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
    if (isDisposed || _isSavingAvailability) return false;
    _isSavingAvailability = true;
    _invalidateLoads();
    _errorMessage = null;
    _refreshWarning = null;
    notifyListeners();
    try {
      final saved = block.id.isEmpty
          ? await _availabilityRepository.createAvailability(block)
          : await _availabilityRepository.updateAvailability(block);
      if (isDisposed) return true;
      final index = _availability.indexWhere((item) => item.id == saved.id);
      if (index == -1) {
        _availability.add(saved);
      } else {
        _availability[index] = saved;
      }
      _availability.sort((a, b) => a.startAt.compareTo(b.startAt));
      notifyListeners();
      await _refreshHistoryAfterSave();
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not save this time block. Please try again.',
      );
      notifyListeners();
      return false;
    } finally {
      _isSavingAvailability = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAvailability(String blockId) async {
    if (isDisposed || _isSavingAvailability) return false;
    _isSavingAvailability = true;
    _invalidateLoads();
    _errorMessage = null;
    _refreshWarning = null;
    notifyListeners();
    try {
      await _availabilityRepository.deleteAvailability(blockId);
      if (isDisposed) return true;
      _availability.removeWhere((block) => block.id == blockId);
      notifyListeners();
      await _refreshHistoryAfterSave();
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not delete this time block. Please try again.',
      );
      notifyListeners();
      return false;
    } finally {
      _isSavingAvailability = false;
      notifyListeners();
    }
  }

  void _invalidateLoads() {
    ++_loadVersion;
    _isLoading = false;
  }

  bool _belongsToSelectedDay(TaskItem task) {
    if (task.status != TaskStatus.planned) return false;
    if (reservationsForTask(task).isNotEmpty) return true;
    if (task.scheduledStart != null && task.scheduledEnd != null) {
      return DailyCapacity.overlapsDay(
        task.scheduledStart!,
        task.scheduledEnd!,
        _selectedDay,
      );
    }
    return DailyCapacity.sameDay(task.dueAt.toLocal(), _selectedDay);
  }

  List<PlanReservation> reservationsForTask(TaskItem task) => _reservations
      .where(
        (reservation) =>
            reservation.taskId == task.id &&
            DailyCapacity.overlapsDay(
              reservation.startAt,
              reservation.endAt,
              _selectedDay,
            ),
      )
      .toList(growable: false);

  Future<void> _refreshHistoryAfterSave() async {
    final history = _historyRepository;
    if (history == null || isDisposed) return;
    final day = _selectedDay;
    final version = _loadVersion;
    try {
      final totals = await history.loadPreviousWeek(day);
      if (!isDisposed && version == _loadVersion) {
        _previousTotals = totals;
        if (history is SnapshotCaptureStatus) {
          _refreshWarning ??= (history as SnapshotCaptureStatus).captureNotice;
        }
      }
    } catch (_) {
      if (!isDisposed && version == _loadVersion) {
        _refreshWarning =
            'Saved, but workload history could not refresh. Pull to retry.';
      }
    }
  }

  bool _overlapsSelectedDay(AvailabilityBlock block) =>
      DailyCapacity.overlapsDay(block.startAt, block.endAt, _selectedDay);

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  void dispose() {
    ++_loadVersion;
    super.dispose();
  }
}
