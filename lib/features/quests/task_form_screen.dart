import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/enums/task_flexibility.dart';
import '../../domain/enums/load_category.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/models/task_item.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.task});

  final TaskItem? task;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _minutesController;
  late DateTime _dueAt;
  late TaskFlexibility _flexibility;
  late TaskStatus _status;
  late bool _isProtected;
  String? _protectedCommitmentType;
  late bool _isOptional;
  late bool _isScheduled;
  LoadCategory? _loadCategory;
  DateTime? _scheduledStart;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _minutesController = TextEditingController(
      text: task?.estimatedMinutes.toString() ?? '',
    );
    _dueAt =
        task?.dueAt.toLocal() ?? DateTime.now().add(const Duration(days: 1));
    _flexibility = task?.flexibility ?? TaskFlexibility.flexible;
    _status = task?.status ?? TaskStatus.planned;
    _isProtected = task?.isProtected ?? false;
    _protectedCommitmentType = task?.protectedCommitmentType;
    _isOptional = task?.isOptional ?? false;
    _loadCategory = task?.loadCategory;
    _scheduledStart = task?.scheduledStart?.toLocal();
    _isScheduled = _scheduledStart != null;
  }

  @override
  void dispose() {
    _titleController.dispose();
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
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit task' : 'New task',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              autofocus: !_isEditing,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Prepare project demo',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a task title.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minutesController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimated minutes',
                hintText: '60',
              ),
              validator: (value) {
                final minutes = int.tryParse(value ?? '');
                if (minutes == null || minutes <= 0) {
                  return 'Enter a number greater than zero.';
                }
                if (_isEditing &&
                    widget.task!.remainingAfterEstimate(minutes) < 0) {
                  return 'Duration cannot be below already allocated work.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Due date and time'),
              subtitle: Text(DateFormat.yMMMd().add_jm().format(_dueAt)),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: _pickDueAt,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LoadCategory>(
              initialValue: _loadCategory,
              decoration: const InputDecoration(labelText: 'Task category'),
              items: [
                for (final category in LoadCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
              ],
              validator: (value) => value == null
                  ? 'Choose a task category before saving.'
                  : null,
              onChanged: (value) => setState(() => _loadCategory = value),
            ),
            if (_isEditing && widget.task!.loadCategory == null) ...[
              const SizedBox(height: 6),
              const Text('Choose a category for this older task.'),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<TaskFlexibility>(
              initialValue: _flexibility,
              decoration: const InputDecoration(labelText: 'Flexibility'),
              items: const [
                DropdownMenuItem(
                  value: TaskFlexibility.flexible,
                  child: Text('Flexible'),
                ),
                DropdownMenuItem(
                  value: TaskFlexibility.fixed,
                  child: Text('Fixed'),
                ),
                DropdownMenuItem(
                  value: TaskFlexibility.needsAgreement,
                  child: Text('Needs agreement'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _flexibility = value);
              },
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(
                    value: TaskStatus.planned,
                    child: Text('Planned'),
                  ),
                  DropdownMenuItem(
                    value: TaskStatus.completed,
                    child: Text('Completed'),
                  ),
                  DropdownMenuItem(
                    value: TaskStatus.cancelled,
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
            ],
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Protected task'),
              value: _isProtected,
              onChanged: (value) => setState(() => _isProtected = value),
            ),
            if (_isProtected)
              DropdownButtonFormField<String?>(
                initialValue: _protectedCommitmentType,
                decoration: const InputDecoration(
                  labelText: 'Protected commitment type',
                ),
                items: const [
                  DropdownMenuItem(
                    value: null,
                    child: Text('Other protected task'),
                  ),
                  DropdownMenuItem(
                    value: 'work_shift',
                    child: Text('Work shift'),
                  ),
                  DropdownMenuItem(
                    value: 'family_duty',
                    child: Text('Family duty'),
                  ),
                  DropdownMenuItem(
                    value: 'sleep_minimum',
                    child: Text('Sleep minimum'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _protectedCommitmentType = value),
              ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Optional task'),
              value: _isOptional,
              onChanged: (value) => setState(() => _isOptional = value),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Schedule work time'),
              value: _isScheduled,
              onChanged: (value) => setState(() {
                _isScheduled = value;
                if (value) {
                  _scheduledStart ??= DateTime.now().add(
                    const Duration(hours: 1),
                  );
                }
              }),
            ),
            if (_isScheduled) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('Planned start'),
                subtitle: Text(
                  _scheduledStart == null
                      ? 'Choose date and time'
                      : DateFormat.yMMMd().add_jm().format(_scheduledStart!),
                ),
                trailing: const Icon(Icons.schedule),
                onTap: _pickScheduledStart,
              ),
              if (_scheduledStart != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ends ${DateFormat.yMMMd().add_jm().format(_scheduledStart!.add(Duration(minutes: _scheduledMinutes)))}',
                ),
              ],
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submit,
              child: Text(_isEditing ? 'Save changes' : 'Create task'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _pickDueAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  int get _scheduledMinutes {
    final estimate = int.tryParse(_minutesController.text) ?? 0;
    final original = widget.task;
    return original == null
        ? estimate
        : original.remainingAfterEstimate(estimate);
  }

  Future<void> _pickScheduledStart() async {
    final current = _scheduledStart ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledStart = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final original = widget.task;
    if (_scheduledMinutes < 0 || (_isScheduled && _scheduledMinutes == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The duration cannot be less than already allocated work. Review the plan first.',
          ),
        ),
      );
      return;
    }
    final scheduledStart = _isScheduled ? _scheduledStart : null;
    final scheduledEnd = scheduledStart?.add(
      Duration(minutes: _scheduledMinutes),
    );
    if (_isScheduled &&
        (scheduledStart == null ||
            scheduledEnd == null ||
            scheduledEnd.isAfter(_dueAt))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Planned work must end before the task deadline.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      TaskItem(
        id: original?.id ?? '',
        version: original?.version ?? 1,
        title: _titleController.text.trim(),
        estimatedMinutes: int.parse(_minutesController.text),
        remainingMinutes: _scheduledMinutes,
        dueAt: _dueAt,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        flexibility: _flexibility,
        status: _status,
        isProtected: _isProtected,
        protectedCommitmentType: _isProtected ? _protectedCommitmentType : null,
        isOptional: _isOptional,
        loadCategory: _loadCategory,
      ),
    );
  }
}
