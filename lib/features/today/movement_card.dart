import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/movement_models.dart';

class MovementCard extends StatelessWidget {
  const MovementCard({
    super.key,
    required this.selectedDay,
    required this.settings,
    required this.latestExercise,
    required this.dayLogs,
    required this.isSaving,
    required this.onTrackingChanged,
    required this.onTargetDaysChanged,
    required this.onAdd,
    required this.onDelete,
  });

  final DateTime selectedDay;
  final MovementSettings settings;
  final ExerciseLog? latestExercise;
  final List<ExerciseLog> dayLogs;
  final bool isSaving;
  final ValueChanged<bool> onTrackingChanged;
  final ValueChanged<int> onTargetDaysChanged;
  final VoidCallback onAdd;
  final ValueChanged<ExerciseLog> onDelete;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isFutureDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    ).isAfter(DateTime(today.year, today.month, today.day));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Movement', style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Track movement'),
              value: settings.trackingEnabled,
              onChanged: isSaving ? null : onTrackingChanged,
            ),
            if (settings.trackingEnabled) ...[
              Row(
                children: [
                  const Expanded(child: Text('Preferred interval')),
                  DropdownButton<int>(
                    value: settings.targetDays,
                    onChanged: isSaving
                        ? null
                        : (value) {
                            if (value != null) onTargetDaysChanged(value);
                          },
                    items: [
                      for (var days = 1; days <= 14; days++)
                        DropdownMenuItem(
                          value: days,
                          child: Text('$days days'),
                        ),
                    ],
                  ),
                ],
              ),
              Text(
                latestExercise == null
                    ? 'No exercise recorded'
                    : 'Last: ${DateFormat.yMMMd().format(latestExercise!.occurredAt.toLocal())}',
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: isSaving || isFutureDay ? null : onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Record exercise'),
              ),
              if (isFutureDay)
                const Text('You can record an activity after it happens.'),
              for (final log in dayLogs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.directions_run_outlined),
                  title: Text('${log.durationMinutes} minutes recorded'),
                  subtitle: Text(
                    DateFormat.jm().format(log.occurredAt.toLocal()),
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove exercise record',
                    onPressed: isSaving ? null : () => onDelete(log),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class ExerciseLogSheet extends StatefulWidget {
  const ExerciseLogSheet({super.key, required this.day});
  final DateTime day;

  @override
  State<ExerciseLogSheet> createState() => _ExerciseLogSheetState();
}

class _ExerciseLogSheetState extends State<ExerciseLogSheet> {
  final _minutesController = TextEditingController();
  late TimeOfDay _time;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final isToday =
        now.year == widget.day.year &&
        now.month == widget.day.month &&
        now.day == widget.day.day;
    _time = isToday
        ? TimeOfDay.fromDateTime(now)
        : const TimeOfDay(hour: 18, minute: 0);
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            'Record actual exercise',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Only save an activity you completed. This does not change your planned tasks.',
          ),
          const SizedBox(height: 16),
          Text('Date: ${DateFormat.yMMMMd().format(widget.day)}'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Time completed'),
            subtitle: Text(_time.format(context)),
            trailing: const Icon(Icons.schedule),
            onTap: _pickTime,
          ),
          TextField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Actual duration in minutes',
              hintText: '30',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(onPressed: _save, child: const Text('Save exercise')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickTime() async {
    final choice = await showTimePicker(context: context, initialTime: _time);
    if (choice != null && mounted) setState(() => _time = choice);
  }

  void _save() {
    final minutes = int.tryParse(_minutesController.text.trim());
    if (minutes == null || minutes < 1 || minutes > 1440) {
      setState(() => _error = 'Enter a duration from 1 to 1440 minutes.');
      return;
    }
    final occurredAt = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      _time.hour,
      _time.minute,
    );
    if (occurredAt.isAfter(DateTime.now())) {
      setState(() => _error = 'Choose a time that has already passed.');
      return;
    }
    Navigator.pop(
      context,
      ExerciseLog(id: '', occurredAt: occurredAt, durationMinutes: minutes),
    );
  }
}
