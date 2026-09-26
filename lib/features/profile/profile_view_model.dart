import 'package:flutter/foundation.dart';

import '../../core/utils/app_error_message.dart';
import '../../data/repositories/availability_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../domain/enums/plan_status.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/models/availability_block.dart';
import '../../domain/models/app_profile.dart';
import '../../domain/models/plan_change.dart';
import '../../domain/models/plan_reservation.dart';
import '../../domain/models/recovery_slot.dart';
import '../../domain/models/task_item.dart';
import '../../domain/usecases/daily_capacity.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel(
    this._taskRepository,
    this._availabilityRepository, [
    this._planRepository,
    this._recoveryRepository,
    this._profileRepository,
  ]);

  final TaskRepository _taskRepository;
  final AvailabilityRepository _availabilityRepository;
  final PlanRepository? _planRepository;
  final RecoveryRepository? _recoveryRepository;
  final ProfileRepository? _profileRepository;

  List<TaskItem> _tasks = const [];
  List<AvailabilityBlock> _availability = const [];
  List<PlanChange> _plans = const [];
  List<PlanReservation> _reservations = const [];
  List<RecoverySlot> _recovery = const [];
  AppProfile? _userProfile;
  bool _isLoading = false;
  bool _isSavingTimeZone = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isSavingTimeZone => _isSavingTimeZone;
  String? get errorMessage => _errorMessage;
  AppProfile? get userProfile => _userProfile;
  bool get canEditTimeZone => _profileRepository != null;
  bool get isCloudConnected => _planRepository != null;
  int get plannedTaskCount =>
      _tasks.where((task) => task.status == TaskStatus.planned).length;
  int get completedTaskCount =>
      _tasks.where((task) => task.status == TaskStatus.completed).length;
  int? get confirmedPlanCount => _planRepository == null
      ? null
      : _plans.where((plan) => plan.status == PlanStatus.confirmed).length;

  DailyCapacity get todayCapacity => DailyCapacity.forDay(
    day: DateTime.now(),
    tasks: _tasks,
    availability: _availability,
    reservations: _reservations,
    recoverySlots: _recovery,
  );

  /// A workload proxy, not a measurement of the person's mental health.
  int get stressMeterPercent {
    final capacity = todayCapacity;
    if (capacity.plannedMinutes == 0) return 0;
    final utilization = capacity.availableMinutes == 0
        ? 1.0
        : capacity.plannedMinutes / capacity.availableMinutes;
    final deadlinePressure = capacity.overloadMinutes / capacity.plannedMinutes;
    final ratio = utilization > deadlinePressure
        ? utilization
        : deadlinePressure;
    return (ratio * 100).clamp(0, 100).round();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _taskRepository.fetchTasks(),
        _availabilityRepository.fetchAvailability(),
        if (_planRepository != null) _planRepository.fetchPlanChanges(),
        if (_planRepository != null) _planRepository.fetchPlanReservations(),
        if (_recoveryRepository != null)
          _recoveryRepository.fetchRecoverySlots(),
        if (_profileRepository != null) _profileRepository.fetchProfile(),
      ]);
      var index = 0;
      _tasks = results[index++] as List<TaskItem>;
      _availability = results[index++] as List<AvailabilityBlock>;
      _plans = _planRepository == null
          ? const []
          : results[index++] as List<PlanChange>;
      _reservations = _planRepository == null
          ? const []
          : results[index++] as List<PlanReservation>;
      _recovery = _recoveryRepository == null
          ? const []
          : results[index++] as List<RecoverySlot>;
      _userProfile = _profileRepository == null
          ? null
          : results[index] as AppProfile;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not load your profile. Please try again.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveTimeZone(String timeZone) async {
    final repository = _profileRepository;
    if (repository == null || _isSavingTimeZone) return false;
    final value = timeZone.trim();
    if (value.isEmpty) {
      _errorMessage = 'Enter an IANA time zone such as Asia/Kuala_Lumpur.';
      notifyListeners();
      return false;
    }
    _isSavingTimeZone = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _userProfile = await repository.updateTimeZone(value);
      return true;
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not update the time zone. Please try again.',
      );
      return false;
    } finally {
      _isSavingTimeZone = false;
      notifyListeners();
    }
  }
}
