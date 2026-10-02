import '../../core/state/lifecycle_notifier.dart';

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
import '../../data/repositories/check_in_repository.dart';
import '../../data/repositories/movement_repository.dart';
import '../../data/repositories/social_repository.dart';
import '../today/today_view_model.dart';
import '../../domain/usecases/world_status_calculator.dart';

class ProfileViewModel extends LifecycleNotifier {
  ProfileViewModel(
    TaskRepository taskRepository,
    AvailabilityRepository availabilityRepository, [
    this._planRepository,
    RecoveryRepository? recoveryRepository,
    this._profileRepository,
    CheckInRepository? checkIns,
    MovementRepository? movement,
    SocialRepository? social,
  ]) : _worldStatus = TodayViewModel(
         taskRepository,
         availabilityRepository,
         _planRepository,
         recoveryRepository,
         null,
         checkIns,
         movement,
         social,
       );

  final TodayViewModel _worldStatus;

  final PlanRepository? _planRepository;
  final ProfileRepository? _profileRepository;

  List<TaskItem> _tasks = const [];
  List<AvailabilityBlock> _availability = const [];
  List<PlanChange> _plans = const [];
  List<PlanReservation> _reservations = const [];
  List<RecoverySlot> _recovery = const [];
  AppProfile? _userProfile;
  bool _isLoading = false;
  int _loadVersion = 0;
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

  WorldStatusResult get worldStatus => _worldStatus.worldStatus;
  int? get stressMeterPercent => worldStatus.totalScore;

  @override
  void dispose() {
    ++_loadVersion;
    _worldStatus.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (isDisposed) return;
    final version = ++_loadVersion;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _worldStatus.selectDay(DateTime.now(), reload: false);
      await _worldStatus.load();
      if (isDisposed || version != _loadVersion) return;
      if (_worldStatus.errorMessage != null) {
        _errorMessage = _worldStatus.errorMessage;
        return;
      }
      _tasks = _worldStatus.allTasks;
      _availability = _worldStatus.allAvailability;
      _reservations = _worldStatus.allReservations;
      _recovery = _worldStatus.allRecoverySlots;
      final results = await Future.wait<Object>([
        if (_planRepository != null) _planRepository.fetchPlanChanges(),
        if (_profileRepository != null) _profileRepository.fetchProfile(),
      ]);
      if (isDisposed || version != _loadVersion) return;
      var index = 0;
      _plans = _planRepository == null
          ? const []
          : results[index++] as List<PlanChange>;
      _userProfile = _profileRepository == null
          ? null
          : results[index] as AppProfile;
    } catch (error) {
      if (isDisposed || version != _loadVersion) return;
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not load your profile. Please try again.',
      );
    } finally {
      if (!isDisposed && version == _loadVersion) {
        _isLoading = false;
        notifyListeners();
      }
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
