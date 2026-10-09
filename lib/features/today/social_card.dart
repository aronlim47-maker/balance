import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/social_event_record.dart';
import '../../domain/models/task_item.dart';
import '../../domain/usecases/world_status_calculator.dart';

class SocialCard extends StatelessWidget {
  const SocialCard({
    super.key,
    required this.events,
    required this.noCommitments,
    required this.isSaving,
    required this.onAdd,
    required this.onDelete,
    required this.onNoCommitmentsChanged,
  });

  final List<SocialEventRecord> events;
  final bool noCommitments;
  final bool isSaving;
  final VoidCallback onAdd;
  final ValueChanged<SocialEventRecord> onDelete;
  final ValueChanged<bool> onNoCommitmentsChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: const Text('Social'),
      subtitle: Text(
        events.isNotEmpty
            ? '${events.length} event${events.length == 1 ? '' : 's'} this week'
            : noCommitments
            ? 'No commitments this week'
            : 'Not recorded',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('No commitments this week'),
          value: noCommitments,
          onChanged: isSaving || events.isNotEmpty
              ? null
              : onNoCommitmentsChanged,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: isSaving ? null : onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add event'),
          ),
        ),
        for (final event in events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              DateFormat.MMMd().add_jm().format(event.startAt.toLocal()),
            ),
            subtitle: Text(
              '${event.endAt.difference(event.startAt).inMinutes} min · ${_pressureLabel(event.pressure)}',
            ),
            trailing: IconButton(
              tooltip: 'Remove social event',
              onPressed: isSaving ? null : () => onDelete(event),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
      ],
    ),
  );

  static String _pressureLabel(SocialPressure pressure) => switch (pressure) {
    SocialPressure.neutral => 'Neutral',
    SocialPressure.low => 'Low',
    SocialPressure.moderate => 'Moderate',
    SocialPressure.high => 'High',
  };
}

class SocialEventSheet extends StatefulWidget {
  const SocialEventSheet({super.key, required this.day, this.tasks = const []});
  final DateTime day;
  final List<TaskItem> tasks;

  @override
  State<SocialEventSheet> createState() => _SocialEventSheetState();
}

class _SocialEventSheetState extends State<SocialEventSheet> {
  final _minutes = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  SocialPressure? _pressure;
  String? _taskId;
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
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
            'Add social event',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(DateFormat.yMMMMd().format(widget.day)),
          if (widget.tasks.isNotEmpty) DropdownButtonFormField<String?>(
            initialValue: _taskId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Linked social task (optional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('No linked task')),
              for (final task in widget.tasks)
                DropdownMenuItem(value: task.id, child: Text(task.title,
                    overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) => setState(() {
              _taskId = value;
              final task = widget.tasks.where((item) => item.id == value).firstOrNull;
              final start = task?.scheduledStart?.toLocal();
              if (start != null && start.year == widget.day.year &&
                  start.month == widget.day.month && start.day == widget.day.day) {
                _time = TimeOfDay.fromDateTime(start);
                _minutes.text = task!.scheduledEnd!.difference(task.scheduledStart!).inMinutes.toString();
              }
            }),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start time'),
            subtitle: Text(_time.format(context)),
            onTap: () async {
              final chosen = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (chosen != null && mounted) setState(() => _time = chosen);
            },
          ),
          TextField(
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Duration in minutes'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SocialPressure>(
            initialValue: _pressure,
            decoration: const InputDecoration(labelText: 'Pressure'),
            items: [
              for (final pressure in SocialPressure.values)
                DropdownMenuItem(
                  value: pressure,
                  child: Text(SocialCard._pressureLabel(pressure)),
                ),
            ],
            onChanged: (value) => setState(() => _pressure = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(onPressed: _save, child: const Text('Save event')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );

  void _save() {
    final minutes = int.tryParse(_minutes.text.trim());
    if (minutes == null || minutes < 1 || minutes > 720 || _pressure == null) {
      setState(
            () => _error = 'Enter 1–720 minutes and choose a pressure level.',
      );
      return;
    }
    final start = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      _time.hour,
      _time.minute,
    );
    Navigator.pop(
      context,
      SocialEventRecord(
        id: '',
        startAt: start,
        endAt: start.add(Duration(minutes: minutes)),
        pressure: _pressure!,
        taskId: _taskId,
      ),
    );
  }
}
