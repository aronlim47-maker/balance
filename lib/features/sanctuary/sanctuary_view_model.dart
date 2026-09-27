import 'package:flutter/foundation.dart';
import '../../core/utils/app_error_message.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../domain/models/recovery_slot.dart';

class SanctuaryViewModel extends ChangeNotifier {
  SanctuaryViewModel(this.repository);
  final RecoveryRepository? repository;
  List<RecoverySlot> slots = [];
  bool busy = false;
  String? error;

  Future<void> load() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      slots = await repository?.fetchRecoverySlots() ?? [];
    } catch (e) {
      error = AppErrorMessage.from(e, fallback: 'Could not load recovery time. Try again.');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> save(RecoverySlot slot) async {
    if (busy || repository == null) return false;
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
    if (slots.any((other) => other.id != slot.id &&
        other.startAt.isBefore(slot.endAt) && other.endAt.isAfter(slot.startAt))) {
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
    if (busy || repository == null || slot.planChangeId != null) return false;
    return _mutate(() => repository!.deleteRecoverySlot(slot.id));
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = AppErrorMessage.from(e, fallback:
          'Could not save recovery time. Check availability and try again.');
      busy = false;
      notifyListeners();
      return false;
    }
    await load();
    return true;
  }
}
