import '../../core/state/lifecycle_notifier.dart';

import '../../core/state/planning_day_controller.dart';
import '../../core/utils/app_error_message.dart';
import '../../data/repositories/availability_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../domain/enums/plan_status.dart';
import '../../domain/enums/task_flexibility.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/enums/validation_status.dart';
import '../../domain/models/availability_block.dart';
import '../../domain/models/plan_change.dart';
import '../../domain/models/plan_reservation.dart';
import '../../domain/models/recovery_slot.dart';
import '../../domain/models/task_item.dart';
import '../../domain/usecases/daily_capacity.dart';
import '../../domain/usecases/generate_trade_offs.dart';
import '../../domain/usecases/validate_plan.dart';

class WarCouncilViewModel extends LifecycleNotifier {
  WarCouncilViewModel(
    this._taskRepository,
    this._availabilityRepository,
    this._planningDayController, [
    this._planRepository,
    this._recoveryRepository,
  ]);

  final TaskRepository _taskRepository;
  final AvailabilityRepository _availabilityRepository;
  final PlanningDayController _planningDayController;
  final PlanRepository? _planRepository;
  final RecoveryRepository? _recoveryRepository;
  final List<TaskItem> _tasks = [];
  final List<AvailabilityBlock> _availability = [];
  final List<PlanReservation> _reservations = [];
  final List<RecoverySlot> _recoverySlots = [];
  List<TradeOffPlan> _options = const [];
  String? _selectedOptionId;
  bool _isSaving = false;
  bool _isLoading = false;
  bool _wasUndone = false;
  bool _migrationReady = false;
  bool _isCheckingCapacity = false;
  bool _isLoadingChange = false;
  bool _changeNotFound = false;
  int? _serverOverloadMinutes;
  int _capacityCheckId = 0;
  int _loadVersion = 0;
  int _changeVersion = 0;
  String? _capacityCheckError;
  String? _errorMessage;
  String? _refreshWarning;
  PlanChange? _currentChange;
  TradeOffPlan? _confirmedOption;

  DateTime get selectedDay => _planningDayController.selectedDay;
  List<TradeOffPlan> get options => List.unmodifiable(_options);
  List<TaskItem> get protectedTasks => List.unmodifiable(
    _tasks.where((task) {
      if (task.status != TaskStatus.planned ||
          (!task.isProtected && task.flexibility != TaskFlexibility.fixed)) {
        return false;
      }
      if (task.scheduledStart != null && task.scheduledEnd != null) {
        return DailyCapacity.overlapsDay(
          task.scheduledStart!,
          task.scheduledEnd!,
          selectedDay,
        );
      }
      return DailyCapacity.sameDay(task.dueAt.toLocal(), selectedDay);
    }),
  );
  bool get allDayTasksProtected {
    final dayTasks = _tasks.where(_isTaskOnSelectedDay).toList();
    return dayTasks.isNotEmpty &&
        dayTasks.every(
          (task) =>
              task.isProtected || task.flexibility == TaskFlexibility.fixed,
        );
  }

  bool get hasUnscheduledFlexibleWork => _tasks.any(
    (task) =>
        _isTaskOnSelectedDay(task) &&
        task.scheduledStart == null &&
        !task.isProtected &&
        task.flexibility == TaskFlexibility.flexible,
  );

  bool _isTaskOnSelectedDay(TaskItem task) {
    if (task.status != TaskStatus.planned) return false;
    if (task.scheduledStart != null && task.scheduledEnd != null) {
      return DailyCapacity.overlapsDay(
        task.scheduledStart!,
        task.scheduledEnd!,
        selectedDay,
      );
    }
    return DailyCapacity.sameDay(task.dueAt.toLocal(), selectedDay);
  }

  List<RecoverySlot> get protectedRecoverySlots => List.unmodifiable(
    _recoverySlots.where(
      (slot) =>
          slot.isProtected &&
          DailyCapacity.overlapsDay(slot.startAt, slot.endAt, selectedDay),
    ),
  );
  bool get isLoading => _isLoading;
  bool get migrationReady => _migrationReady;
  bool get isCheckingCapacity => _isCheckingCapacity;
  bool get isLoadingChange => _isLoadingChange;
  bool get changeNotFound => _changeNotFound;
  bool get capacityMatchesServer =>
      _serverOverloadMinutes != null &&
      _serverOverloadMinutes == capacity.overloadMinutes;
  String? get capacityCheckError => _capacityCheckError;
  bool get isConfigured => _planRepository != null;
  String? get errorMessage => _errorMessage;
  String? get refreshWarning => _refreshWarning;
  PlanChange? get currentChange => _currentChange;
  TradeOffPlan? get confirmedOption => _confirmedOption;

  DailyCapacity get capacity => DailyCapacity.forDay(
    day: selectedDay,
    tasks: _tasks,
    availability: _availability,
    reservations: _reservations,
    recoverySlots: _recoverySlots,
  );

  String? get selectedOptionId => _selectedOptionId;
  bool get isSaving => _isSaving;
  bool get wasUndone => _wasUndone;
  bool get canUndoCurrentChange =>
      _currentChange?.status == PlanStatus.confirmed &&
      !_wasUndone &&
      !_isSaving;
  TradeOffPlan? get selectedOption =>
      _options.where((option) => option.id == _selectedOptionId).firstOrNull;
  ValidationStatus get validationStatus {
    final informationReady =
        _errorMessage == null &&
        _capacityCheckError == null &&
        _migrationReady &&
        !_isLoading &&
        !_isCheckingCapacity &&
        capacityMatchesServer;
    if (capacity.overloadMinutes == 0 && informationReady) {
      return ValidationStatus.feasible;
    }
    return validatePlan(
      hasRequiredInformation: informationReady,
      hasFeasibleCapacity: selectedOption != null,
      needsAgreement: selectedOption?.needsAgreement ?? false,
    );
  }

  bool get canConfirm =>
      validationStatus == ValidationStatus.feasible &&
      selectedOption != null &&
      !_isSaving &&
      !_isLoading;

  Future<void> load({bool afterMutation = false}) async {
    if (isDisposed || (_isSaving && !afterMutation)) return;
    final version = ++_loadVersion;
    ++_capacityCheckId;
    _isCheckingCapacity = false;
    _isLoading = true;
    _errorMessage = null;
    _refreshWarning = null;
    notifyListeners();
    try {
      final tasks = await _taskRepository.fetchTasks();
      if (isDisposed || version != _loadVersion) return;
      final availability = await _availabilityRepository.fetchAvailability();
      if (isDisposed || version != _loadVersion) return;
      final reservations = _planRepository == null
          ? <PlanReservation>[]
          : await _planRepository.fetchPlanReservations();
      if (isDisposed || version != _loadVersion) return;
      final recovery = _recoveryRepository == null
          ? <RecoverySlot>[]
          : await _recoveryRepository.fetchRecoverySlots();
      if (isDisposed || version != _loadVersion) return;
      final migrationReady = _planRepository == null
          ? false
          : await _planRepository.hasWarCouncilMigration();
      if (isDisposed || version != _loadVersion) return;
      _tasks
        ..clear()
        ..addAll(tasks);
      _availability
        ..clear()
        ..addAll(availability);
      _reservations
        ..clear()
        ..addAll(reservations);
      _recoverySlots
        ..clear()
        ..addAll(recovery);
      _migrationReady = migrationReady;
      _regenerateOptions();
      if (_migrationReady) await _checkServerCapacity();
    } catch (error) {
      if (isDisposed || version != _loadVersion) return;
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not load plan options. Please try again.',
      );
      _options = const [];
    } finally {
      if (!isDisposed && version == _loadVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void selectDay(DateTime day) {
    _planningDayController.selectDay(day);
    _regenerateOptions();
    notifyListeners();
    if (_migrationReady) _checkServerCapacity();
  }

  void _regenerateOptions() {
    _options = generateTradeOffs(
      day: selectedDay,
      tasks: _tasks,
      availability: _availability,
      reservations: _reservations,
      recoverySlots: _recoverySlots,
      includeNeedsAgreement: true,
    );
    if (!_options.any((option) => option.id == _selectedOptionId)) {
      _selectedOptionId =
          _options.where((option) => !option.needsAgreement).firstOrNull?.id ??
          _options.firstOrNull?.id;
    }
  }

  Future<void> _checkServerCapacity() async {
    if (isDisposed) return;
    final repository = _planRepository;
    if (repository == null) return;
    final checkId = ++_capacityCheckId;
    final day = selectedDay;
    _isCheckingCapacity = true;
    _serverOverloadMinutes = null;
    _capacityCheckError = null;
    notifyListeners();
    try {
      final overload = await repository.calculateDayOverload(day);
      if (checkId != _capacityCheckId) return;
      _serverOverloadMinutes = overload;
    } catch (error) {
      if (checkId != _capacityCheckId) return;
      _capacityCheckError = AppErrorMessage.from(
        error,
        fallback: 'Could not check capacity. Refresh and try again.',
      );
    } finally {
      if (checkId == _capacityCheckId) {
        _isCheckingCapacity = false;
        notifyListeners();
      }
    }
  }

  void selectOption(String id) {
    if (!_options.any((option) => option.id == id)) return;
    _selectedOptionId = id;
    notifyListeners();
  }

  Future<String?> confirmSelectedPlan() async {
    if (isDisposed || !canConfirm) return null;
    ++_changeVersion;
    _isLoadingChange = false;
    final option = selectedOption!;
    _isSaving = true;
    _errorMessage = null;
    _refreshWarning = null;
    _wasUndone = false;
    notifyListeners();
    try {
      final change = await _planRepository!.confirm(
        moves: [
          PlanMove(
            taskId: option.taskId,
            proposedStart: option.proposedStart,
            proposedEnd: option.proposedEnd,
            movedMinutes: option.movedMinutes,
          ),
        ],
        consequences: {
          'selected_day': selectedDay.toIso8601String(),
          'task_title': option.taskTitle,
          'moved_minutes': option.movedMinutes,
        },
      );
      if (isDisposed) return change.id;
      _currentChange = change;
      _changeNotFound = false;
      _confirmedOption = option;
      return change.id;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not confirm this plan. Please try again.',
      );
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> undoPlan(String changeId) async {
    if (isDisposed ||
        _planRepository == null ||
        !canUndoCurrentChange ||
        _currentChange?.id != changeId) {
      return false;
    }
    _isSaving = true;
    ++_changeVersion;
    ++_loadVersion;
    _isLoadingChange = false;
    _errorMessage = null;
    _refreshWarning = null;
    notifyListeners();
    try {
      await _planRepository.undo(changeId);
      _wasUndone = true;
      await load(afterMutation: true);
      if (_errorMessage != null) {
        _refreshWarning = 'The plan was undone, but the latest plan could not be loaded. Try refreshing.';
        notifyListeners();
      }
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not undo this plan. Please try again.',
      );
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> loadChange(String changeId) async {
    if (isDisposed || _planRepository == null || _isSaving) return;
    final version = ++_changeVersion;
    final keepSuccessfulUndo = _wasUndone && _currentChange?.id == changeId;
    _isLoadingChange = true;
    _changeNotFound = false;
    _errorMessage = null;
    if (_currentChange?.id != changeId) {
      _currentChange = null;
      _confirmedOption = null;
      _wasUndone = false;
    }
    notifyListeners();
    try {
      final changes = await _planRepository.fetchPlanChanges();
      if (isDisposed || version != _changeVersion) return;
      final fetched = changes
          .where((change) => change.id == changeId)
          .firstOrNull;
      final justConfirmed =
          _confirmedOption != null &&
          !_wasUndone &&
          _currentChange?.id == changeId &&
          _currentChange?.status == PlanStatus.confirmed;
      _currentChange = fetched ?? (justConfirmed ? _currentChange : null);
      _changeNotFound = _currentChange == null;
      _wasUndone =
          keepSuccessfulUndo || _currentChange?.status == PlanStatus.undone;
    } catch (error) {
      if (isDisposed || version != _changeVersion) return;
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not load this plan. Please try again.',
      );
    } finally {
      if (!isDisposed && version == _changeVersion) {
        _isLoadingChange = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    ++_loadVersion;
    ++_changeVersion;
    ++_capacityCheckId;
    super.dispose();
  }
}
