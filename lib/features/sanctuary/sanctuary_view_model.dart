import '../../core/state/lifecycle_notifier.dart';

import '../../core/utils/app_error_message.dart';
import '../../data/repositories/availability_repository.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../domain/models/availability_block.dart';
import '../../domain/models/recovery_slot.dart';
import '../../domain/models/task_item.dart';
import '../../domain/usecases/free_windows.dart';

class SanctuaryViewModel extends LifecycleNotifier {
  SanctuaryViewModel(
    this.repository, {
    this.availabilityRepository,
    this.taskRepository,
  });
  final RecoveryRepository? repository;

  /// Optional sources for free-time suggestions; without them the form simply
  /// offers no suggestions.
  final AvailabilityRepository? availabilityRepository;
  final TaskRepository? taskRepository;
  List<RecoverySlot> slots = [];
  List<AvailabilityBlock> _availability = [];
  List<TaskItem> _tasks = [];

  /// Free time on [day] where a recovery slot fits (see [freeWindowsOn]).
  List<FreeWindow> freeWindows(DateTime day, {String? exceptSlotId}) =>
      freeWindowsOn(
        day,
        availability: _availability,
        tasks: _tasks,
        recovery: slots,
        exceptSlotId: exceptSlotId,
        now: DateTime.now(),
      );
  bool _loading = false;
  bool _mutating = false;
  int _loadVersion = 0;
  bool get busy => _loading || _mutating;
  String? error;

  /// True when the last save failed because no availability covers the slot,
  /// so the screen can offer a direct route to Today.
  bool get needsAvailability =>
      error == AppErrorMessage.recoveryNeedsAvailability;

  Future<void> load() async {
    if (isDisposed || _mutating) return;
    await _reload();
  }

  Future<void> _reload() async {
    if (isDisposed) return;
    final version = ++_loadVersion;
    _loading = true;
    error = null;
    notifyListeners();
    try {
      final fetched = await repository?.fetchRecoverySlots() ?? [];
      if (isDisposed || version != _loadVersion) return;
      slots = fetched;
      // Suggestions are a convenience: a failure here never blocks Sanctuary.
      try {
        final availability =
            await availabilityRepository?.fetchAvailability() ?? const [];
        final tasks = await taskRepository?.fetchTasks() ?? const [];
        if (isDisposed || version != _loadVersion) return;
        _availability = availability;
        _tasks = tasks;
      } catch (_) {}
    } catch (e) {
      if (isDisposed || version != _loadVersion) return;
      error = AppErrorMessage.from(
        e,
        fallback: 'Could not load recovery time. Try again.',
      );
    } finally {
      if (!isDisposed && version == _loadVersion) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save(RecoverySlot slot) async {
    if (isDisposed || busy || repository == null) return false;
    if (!slot.endAt.isAfter(slot.startAt) ||
        slot.endAt.difference(slot.startAt).inMinutes < 1) {
      error = 'Choose an end time after the start.';
      notifyListeners();
      return false;
    }
    if (slot.planChangeId != null) {
      error = 'Use Council to undo a plan-created slot.';
      notifyListeners();
      return false;
    }
    if (slots.any(
      (other) =>
          other.id != slot.id &&
          other.startAt.isBefore(slot.endAt) &&
          other.endAt.isAfter(slot.startAt),
    )) {
      error = 'This overlaps another recovery slot.';
      notifyListeners();
      return false;
    }
    return _mutate(() async {
      if (slot.id.isEmpty) {
        await repository!.createRecoverySlot(slot);
      } else {
        await repository!.updateRecoverySlot(slot);
      }
    });
  }

  /// Records (or clears) that the user finished the optional activity.
  ///
  /// This only changes `completedAt`. It never changes the reserved time,
  /// never records energy, and never lowers any workload score.
  Future<bool> setActivityDone(RecoverySlot slot, {required bool done}) async {
    if (isDisposed || busy || repository == null) return false;
    if (slot.planChangeId != null) {
      error = 'Council plan slots can only be changed from Council.';
      notifyListeners();
      return false;
    }
    if (done && DateTime.now().isBefore(slot.startAt)) {
      error = 'You can mark this done once the recovery time has started.';
      notifyListeners();
      return false;
    }
    final updated = RecoverySlot(
      id: slot.id,
      startAt: slot.startAt,
      endAt: slot.endAt,
      isProtected: slot.isProtected,
      planChangeId: slot.planChangeId,
      selectedActivity: slot.selectedActivity,
      completedAt: done ? DateTime.now() : null,
    );
    return _mutate(() async {
      await repository!.updateRecoverySlot(updated);
    });
  }

  Future<bool> remove(RecoverySlot slot) async {
    if (isDisposed || busy || repository == null || slot.planChangeId != null) {
      return false;
    }
    return _mutate(() => repository!.deleteRecoverySlot(slot.id));
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    _mutating = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = AppErrorMessage.from(
        e,
        fallback:
            'Could not save recovery time. Make sure it is inside your '
            'available time on Today, then try again.',
      );
      _mutating = false;
      notifyListeners();
      return false;
    }
    await _reload();
    if (error != null) {
      error = 'Your change was saved, but recovery time could not refresh. Try again.';
      notifyListeners();
    }
    _mutating = false;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    ++_loadVersion;
    super.dispose();
  }
}
