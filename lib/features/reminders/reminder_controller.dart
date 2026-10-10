import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/state/lifecycle_notifier.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/services/device_reminder_gateway.dart';
import '../../domain/models/availability_block.dart';
import '../../domain/usecases/plan_task_reminders.dart';

abstract interface class ReminderStore {
  Future<ReminderPreferences> read(String owner);
  Future<void> write(String owner, ReminderPreferences preferences);
}

class DeviceReminderStore implements ReminderStore {
  late final _prefs = SharedPreferencesAsync();
  String _key(String owner) => 'balance.reminders.v1.$owner';
  @override
  Future<ReminderPreferences> read(String owner) async {
    final raw = await _prefs.getString(_key(owner));
    if (raw == null) return const ReminderPreferences();
    try {
      return ReminderPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const ReminderPreferences();
    }
  }

  @override
  Future<void> write(String owner, ReminderPreferences preferences) =>
      _prefs.setString(_key(owner), jsonEncode(preferences.toJson()));
}

class ReminderController extends LifecycleNotifier {
  ReminderController(
    this._tasks,
    this._gateway,
    this._store, {
    Future<List<AvailabilityBlock>> Function()? fetchAvailability,
    // ignore: prefer_initializing_formals
  }) : _fetchAvailability = fetchAvailability;
  final TaskRepository _tasks;

  /// Source for overload alerts; without it only deadline reminders run.
  final Future<List<AvailabilityBlock>> Function()? _fetchAvailability;
  int overloadAlertCount = 0;
  final ReminderGateway _gateway;
  final ReminderStore _store;
  String? _owner;
  int _generation = 0;
  Future<void> _tail = Future.value();
  ReminderPreferences preferences = const ReminderPreferences();
  String? message;
  int scheduledCount = 0;
  bool busy = false;
  bool get available => _gateway.supported && _owner != null;

  Future<void> _enqueue(Future<void> Function(int) action) {
    final generation = _generation;
    final result = _tail.then((_) async {
      if (isDisposed || generation != _generation) return;
      busy = true;
      notifyListeners();
      try {
        await action(generation);
      } catch (_) {
        if (generation == _generation && !isDisposed) {
          message = 'Could not update reminders. This does not affect saved tasks. Try again.';
        }
      } finally {
        if (!isDisposed && generation == _generation) {
          busy = false;
          notifyListeners();
        }
      }
    });
    _tail = result;
    return result;
  }

  bool _current(int generation) => !isDisposed && generation == _generation;

  Future<void> setOwner(String? owner) {
    _owner = owner;
    ++_generation;
    preferences = const ReminderPreferences();
    scheduledCount = 0;
    message = null;
    busy = false;
    notifyListeners();
    return _enqueue((generation) async {
      if (!_gateway.supported) return;
      await _gateway.initialize();
      await _gateway.cancelAll();
      if (!_current(generation) || owner == null) return;
      final stored = await _store.read(owner);
      if (!_current(generation)) return;
      preferences = stored;
      await _sync(generation);
    });
  }

  Future<void> save(ReminderPreferences value) => _enqueue((generation) async {
    final owner = _owner;
    if (!_gateway.supported || owner == null) return;
    if (!value.isValid) {
      message = 'Choose different quiet-hour start and end times.';
      return;
    }
    await _gateway.initialize();
    if ((value.enabled || value.overloadAlerts) &&
        !await _gateway.permission(request: true)) {
      await _gateway.cancelAll();
      if (!_current(generation)) return;
      scheduledCount = 0;
      message = 'Notifications are blocked. Allow Balance notifications in device settings, then try again.';
      return;
    }
    if (!_current(generation)) return;
    await _store.write(owner, value);
    if (!_current(generation)) return;
    preferences = value;
    await _sync(generation);
  });

  Future<void> refresh() => _enqueue(_sync);

  Future<void> _sync(int generation) async {
    if (!_gateway.supported) return;
    await _gateway.initialize();
    if (!_current(generation)) return;
    message = null;
    if (_owner == null ||
        (!preferences.enabled && !preferences.overloadAlerts)) {
      await _gateway.cancelAll();
      if (_current(generation)) {
        scheduledCount = 0;
        overloadAlertCount = 0;
      }
      return;
    }
    if (!await _gateway.permission()) {
      await _gateway.cancelAll();
      if (_current(generation)) {
        scheduledCount = 0;
        message = 'Notifications are blocked in device settings.';
      }
      return;
    }
    final tasks = await _tasks.fetchTasks();
    final availability = preferences.overloadAlerts
        ? await _fetchAvailability?.call() ?? const <AvailabilityBlock>[]
        : const <AvailabilityBlock>[];
    final location = await _gateway.location();
    if (!_current(generation)) return;
    final overloads = planOverloadAlerts(
      tasks,
      availability,
      preferences,
      DateTime.now(),
      location,
    );
    final reminders = planTaskReminders(
      tasks,
      preferences,
      DateTime.now(),
      location,
    );
    // Preserve existing reminders if obtaining a replacement fails offline.
    await _gateway.cancelAll();
    if (!_current(generation)) return;
    scheduledCount = 0;
    for (var index = 0; index < reminders.length; index++) {
      if (!_current(generation)) {
        await _gateway.cancelAll();
        return;
      }
      try {
        await _gateway.schedule(index + 1, reminders[index]);
      } catch (_) {
        await _gateway.cancelAll();
        rethrow;
      }
    }
    for (var index = 0; index < overloads.length; index++) {
      if (!_current(generation)) {
        await _gateway.cancelAll();
        return;
      }
      // Separate id range so deadline reminders and alerts never collide.
      await _gateway.scheduleOverload(1000 + index, overloads[index]);
    }
    if (!_current(generation)) {
      await _gateway.cancelAll();
      return;
    }
    scheduledCount = reminders.length;
    overloadAlertCount = overloads.length;
  }

  @override
  void dispose() {
    ++_generation;
    super.dispose();
  }
}
