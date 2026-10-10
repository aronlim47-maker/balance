import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/usecases/plan_task_reminders.dart';

abstract interface class ReminderGateway {
  bool get supported;
  Future<void> initialize();
  Future<tz.Location> location();
  Future<bool> permission({bool request = false});
  Future<void> cancelAll();
  Future<void> schedule(int id, TaskReminder reminder);
  Future<void> scheduleOverload(int id, OverloadAlert alert);
}

class DeviceReminderGateway implements ReminderGateway {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> initialize() async {
    if (_initialized || !supported) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_balance'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<tz.Location> location() async =>
      tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier);

  @override
  Future<bool> permission({bool request = false}) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return (request
              ? await android.requestNotificationsPermission()
              : await android.areNotificationsEnabled()) ??
          false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (request) {
      return await ios?.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          ) ??
          false;
    }
    return (await ios?.checkPermissions())?.isEnabled ?? false;
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> schedule(int id, TaskReminder reminder) => _plugin.zonedSchedule(
    id: id,
    title: 'Balance reminder',
    body: 'A task deadline is approaching. Open Quests to review it.',
    scheduledDate: reminder.at,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'task_deadlines_v1',
        'Task deadlines',
        channelDescription: 'Optional deadline reminders',
        visibility: NotificationVisibility.private,
      ),
      iOS: DarwinNotificationDetails(presentBadge: false),
    ),
  );

  @override
  Future<void> scheduleOverload(int id, OverloadAlert alert) {
    final hours = alert.overloadMinutes ~/ 60;
    final minutes = alert.overloadMinutes % 60;
    final amount = hours == 0
        ? '${minutes}m'
        : minutes == 0
        ? '${hours}h'
        : '${hours}h ${minutes}m';
    return _plugin.zonedSchedule(
      id: id,
      title: 'Tomorrow is over capacity',
      body:
          'Planned work is $amount more than your available time. '
          'Open War Council to compare safe options.',
      scheduledDate: alert.at,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'overload_alerts_v1',
          'Overload alerts',
          channelDescription:
              'Optional alerts the evening before an overloaded day',
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(presentBadge: false),
      ),
    );
  }
}
