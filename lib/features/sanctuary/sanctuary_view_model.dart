import '../../core/state/lifecycle_notifier.dart';

import '../../core/utils/app_error_message.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../domain/models/recovery_slot.dart';

class SanctuaryViewModel extends LifecycleNotifier {
  SanctuaryViewModel(this.repository);
  final RecoveryRepository? repository;
  List<RecoverySlot> slots = [];
  bool _loading = false;
  bool _mutating = false;
  int _loadVersion = 0;
  bool get busy => _loading || _mutating;
  String? error;

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
            'Could not save recovery time. Check availability and try again.',
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
