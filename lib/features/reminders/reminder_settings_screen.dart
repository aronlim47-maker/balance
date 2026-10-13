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
      appBar: AppBar(title: const Text('Reminders and alerts')),
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
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Remind me before'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: settings.leadMinutes,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: 15,
                      child: Text('15 minutes'),
                    ),
                    const DropdownMenuItem(
                      value: 30,
                      child: Text('30 minutes'),
                    ),
                    const DropdownMenuItem(value: 60, child: Text('1 hour')),
                    const DropdownMenuItem(value: 1440, child: Text('1 day')),
                    if (![15, 30, 60, 1440].contains(settings.leadMinutes))
                      DropdownMenuItem(
                        value: settings.leadMinutes,
                        child: Text('${settings.leadMinutes} minutes'),
                      ),
                    const DropdownMenuItem(
                      value: -1,
                      child: Text('Custom minutes…'),
                    ),
                  ],
                  onChanged: controller.available && !controller.busy
                      ? (value) async {
                          if (value == null) return;
                          if (value == -1) {
                            final minutes = await _chooseCustomReminderMinutes(
                              context,
                              controller.preferences.leadMinutes,
                            );
                            if (!context.mounted ||
                                minutes == null ||
                                !controller.available ||
                                controller.busy) {
                              return;
                            }
                            controller.save(
                              controller.preferences.copyWith(
                                leadMinutes: minutes,
                              ),
                            );
                          } else {
                            controller.save(
                              controller.preferences.copyWith(
                                leadMinutes: value,
                              ),
                            );
                          }
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Overload alerts'),
              subtitle: const Text(
                'The evening before a day with more planned work than '
                'available time. Off by default.',
              ),
              value: settings.overloadAlerts,
              onChanged: controller.available && !controller.busy
                  ? (value) => controller.save(
                      settings.copyWith(overloadAlerts: value),
                    )
                  : null,
            ),
            ListTile(
              title: const Text('Alert time'),
              trailing: Text(_time(settings.overloadAt).format(context)),
              onTap:
                  controller.available &&
                      !controller.busy &&
                      settings.overloadAlerts
                  ? () => _chooseAlertTime(context, controller)
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
              Text(
                '${controller.scheduledCount} reminders and '
                '${controller.overloadAlertCount} overload alerts scheduled',
              ),
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

  Future<void> _chooseAlertTime(
    BuildContext context,
    ReminderController controller,
  ) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time(controller.preferences.overloadAt),
    );
    if (selected == null || !context.mounted) return;
    await controller.save(
      controller.preferences.copyWith(
        overloadAt: selected.hour * 60 + selected.minute,
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

Future<int?> _chooseCustomReminderMinutes(
  BuildContext context,
  int currentMinutes,
) {
  final formKey = GlobalKey<FormState>();
  var input = currentMinutes.toString();

  return showDialog<int>(
    context: context,
    builder: (dialogContext) {
      void submit() {
        if (formKey.currentState!.validate()) {
          Navigator.of(dialogContext).pop(int.parse(input.trim()));
        }
      }

      return AlertDialog(
        title: const Text('Custom reminder'),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: input,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Minutes before deadline',
              helperText: '1–10080 minutes (up to 7 days)',
            ),
            onChanged: (value) => input = value,
            validator: (value) {
              final text = (value ?? '').trim();
              final minutes = int.tryParse(text);
              if (!RegExp(r'^[0-9]+$').hasMatch(text) ||
                  minutes == null ||
                  minutes < 1 ||
                  minutes > 10080) {
                return 'Enter a whole number from 1 to 10080.';
              }
              return null;
            },
            onFieldSubmitted: (_) => submit(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: submit, child: const Text('Save')),
        ],
      );
    },
  );
}
