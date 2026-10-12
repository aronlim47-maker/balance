import 'dart:convert';

import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/domain/usecases/plan_task_reminders.dart';
import 'package:balance/features/reminders/reminder_controller.dart';
import 'package:balance/features/reminders/reminder_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import 'task_reminders_test.dart' show FakeGateway, task;

class JsonReminderStore implements ReminderStore {
  final values = <String, String>{};
  int writes = 0;
  @override
  Future<ReminderPreferences> read(String owner) async => values[owner] == null
      ? const ReminderPreferences()
      : ReminderPreferences.fromJson(
          jsonDecode(values[owner]!) as Map<String, dynamic>,
        );
  @override
  Future<void> write(String owner, ReminderPreferences preferences) async {
    writes++;
    values[owner] = jsonEncode(preferences.toJson());
  }
}

Future<void> openCustom(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButton<int>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Custom minutes…').last);
  await tester.pumpAndSettle();
}

void main() {
  for (final minutes in [1, 45, 10080]) {
    test(
      'custom $minutes minutes survives JSON and schedules exact instant',
      () {
        final preferences = ReminderPreferences.fromJson(
          jsonDecode(
            jsonEncode(
              ReminderPreferences(
                enabled: true,
                quietEnabled: false,
                leadMinutes: minutes,
              ).toJson(),
            ),
          ) as Map<String, dynamic>,
        );
        expect(preferences.leadMinutes, minutes);
        final now = DateTime.utc(2030, 1, 1);
        final due = now.add(const Duration(days: 10));
        final reminders = planTaskReminders(
          [task('a', due)],
          preferences,
          now,
          tz.UTC,
        );
        expect(reminders.single.at, due.subtract(Duration(minutes: minutes)));
        expect(
          planTaskReminders(
            [task('a', now.add(Duration(minutes: minutes)))],
            preferences,
            now,
            tz.UTC,
          ),
          isEmpty,
        );
      },
    );
  }
  test('invalid stored minutes fall back safely', () {
    for (final minutes in [-1, 0, 10081]) {
      final value = ReminderPreferences(enabled: true, leadMinutes: minutes);
      expect(value.isValid, isFalse);
      expect(ReminderPreferences.fromJson(value.toJson()).leadMinutes, 30);
    }
  });
  testWidgets(
    'cancel and dismiss preserve settings; save reloads and reschedules',
    (tester) async {
      final store = JsonReminderStore();
      final gateway = FakeGateway();
      final tasks = LocalTaskRepository();
      final due = DateTime.now().toUtc().add(const Duration(days: 10));
      await tasks.createTask(task('', due));
      final controller = ReminderController(tasks, gateway, store);
      addTearDown(controller.dispose);
      await controller.setOwner('a');
      await controller.save(
        const ReminderPreferences(enabled: true, quietEnabled: false),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(home: ReminderSettingsScreen()),
        ),
      );
      await openCustom(tester);
      await tester.enterText(find.byType(TextFormField), '45');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.preferences.leadMinutes, 30);
      expect(store.writes, 1);
      await openCustom(tester);
      await tester.enterText(find.byType(TextFormField), '90');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(controller.preferences.leadMinutes, 30);
      expect(store.writes, 1);
      for (final minutes in [1, 45, 10080, 60]) {
        await openCustom(tester);
        for (final invalid in ['', '0', '-1', '10081', '1.5', 'abc']) {
          await tester.enterText(find.byType(TextFormField), invalid);
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
          expect(
            find.text('Enter a whole number from 1 to 10080.'),
            findsOneWidget,
          );
          expect(find.byType(AlertDialog), findsOneWidget);
        }
        await tester.enterText(find.byType(TextFormField), '$minutes');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(controller.preferences.leadMinutes, minutes);
        expect(
          gateway.scheduled.single.at,
          due.subtract(Duration(minutes: minutes)),
        );
        expect(tester.takeException(), isNull);
        final restartedGateway = FakeGateway();
        final restarted = ReminderController(tasks, restartedGateway, store);
        await restarted.setOwner('a');
        expect(restarted.preferences.leadMinutes, minutes);
        expect(restartedGateway.requests, 0);
        expect(
          restartedGateway.scheduled.single.at,
          due.subtract(Duration(minutes: minutes)),
        );
        restarted.dispose();
      }
    },
  );
}
