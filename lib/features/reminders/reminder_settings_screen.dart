import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'reminder_controller.dart';

class ReminderSettingsScreen extends StatelessWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReminderController>();
    final settings = controller.preferences;
    return Scaffold(
      appBar: AppBar(title: const Text('Task reminders')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!controller.available)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Sign in on Android or iOS to use device reminders.',
                  ),
                ),
              ),
            SwitchListTile(
              title: const Text('Deadline reminders'),
              subtitle: const Text('Only on this device. Off by default.'),
              value: settings.enabled,
              onChanged: controller.available && !controller.busy
                  ? (value) =>
                        controller.save(settings.copyWith(enabled: value))
                  : null,
            ),
            DropdownButtonFormField<int>(
              key: ValueKey(settings.leadMinutes),
              initialValue: settings.leadMinutes,
              decoration: const InputDecoration(labelText: 'Remind me before'),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 minutes')),
                DropdownMenuItem(value: 30, child: Text('30 minutes')),
                DropdownMenuItem(value: 60, child: Text('1 hour')),
                DropdownMenuItem(value: 1440, child: Text('1 day')),
              ],
              onChanged: controller.available && !controller.busy
                  ? (value) {
                      if (value != null) {
                        controller.save(settings.copyWith(leadMinutes: value));
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Quiet hours'),
              subtitle: const Text('Reminders in this period are skipped.'),
              value: settings.quietEnabled,
              onChanged: controller.available && !controller.busy
                  ? (value) =>
                        controller.save(settings.copyWith(quietEnabled: value))
                  : null,
            ),
            ListTile(
              title: const Text('Start'),
              trailing: Text(_time(settings.quietStart).format(context)),
              onTap:
                  controller.available &&
                      !controller.busy &&
                      settings.quietEnabled
                  ? () => _chooseTime(context, controller, true)
                  : null,
            ),
            ListTile(
              title: const Text('End'),
              trailing: Text(_time(settings.quietEnd).format(context)),
              onTap:
                  controller.available &&
                      !controller.busy &&
                      settings.quietEnabled
                  ? () => _chooseTime(context, controller, false)
                  : null,
            ),
            if (controller.busy) const LinearProgressIndicator(),
            if (controller.message != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(controller.message!),
                ),
              ),
            if (controller.available) ...[
              Text('${controller.scheduledCount} reminders scheduled'),
              TextButton.icon(
                onPressed: controller.busy ? null : controller.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh reminders'),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Uses your device time zone. Task names stay private. Delivery may be delayed by battery settings.',
            ),
            ExpansionTile(
              title: const Text('How reminders work'),
              children: const [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Only unfinished tasks with future reminder times are included, up to the nearest 50 deadlines. '
                    'Completed, cancelled and deleted tasks are removed. Changes made on another device are picked up '
                    'when Balance resumes or you refresh. This does not reschedule work or send remote push notifications.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static TimeOfDay _time(int minute) =>
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60);

  Future<void> _chooseTime(
    BuildContext context,
    ReminderController controller,
    bool start,
  ) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time(
        start
            ? controller.preferences.quietStart
            : controller.preferences.quietEnd,
      ),
    );
    if (selected == null || !context.mounted) return;
    final minute = selected.hour * 60 + selected.minute;
    await controller.save(
      start
          ? controller.preferences.copyWith(quietStart: minute)
          : controller.preferences.copyWith(quietEnd: minute),
    );
  }
}
