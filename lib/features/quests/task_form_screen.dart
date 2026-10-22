import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/balance_colors.dart';

import '../../domain/enums/task_flexibility.dart';
import '../../domain/enums/load_category.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/models/task_item.dart';
import '../../core/l10n/tr.dart';

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
                    _isEditing ? 'Edit task'.tr : 'New task'.tr,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Close'.tr,
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
              decoration: InputDecoration(
                labelText: 'Title'.tr,
                hintText: 'Prepare project demo'.tr,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a task title.'.tr
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minutesController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Estimated minutes'.tr,
                hintText: '60',
              ),
              validator: (value) {
                final minutes = int.tryParse(value ?? '');
                if (minutes == null || minutes <= 0) {
                  return 'Enter a number greater than zero.'.tr;
                }
                if (_isEditing &&
                    widget.task!.remainingAfterEstimate(minutes) < 0) {
                  return 'Duration cannot be below already allocated work.'.tr;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              tileColor: BalanceColors.surfaceSunken,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text('Due date and time'.tr),
              subtitle: Text(DateFormat.yMMMd().add_jm().format(_dueAt)),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: _pickDueAt,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LoadCategory>(
              initialValue: _loadCategory,
              decoration: InputDecoration(
                labelText: 'Task category'.tr,
                helperText: _categoryHelp(_loadCategory),
                helperMaxLines: 3,
              ),
              items: [
                for (final category in LoadCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
              ],
              validator: (value) => value == null
                  ? 'Choose a task category before saving.'.tr
                  : null,
              onChanged: (value) => setState(() => _loadCategory = value),
            ),
            if (_isEditing && widget.task!.loadCategory == null) ...[
              const SizedBox(height: 6),
              Text('Choose a category for this older task.'.tr),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<TaskFlexibility>(
              initialValue: _flexibility,
              decoration: InputDecoration(labelText: 'Flexibility'.tr),
              items: [
                DropdownMenuItem(
                  value: TaskFlexibility.flexible,
                  child: Text('Flexible'.tr),
                ),
                DropdownMenuItem(
                  value: TaskFlexibility.fixed,
                  child: Text('Fixed'.tr),
                ),
                DropdownMenuItem(
                  value: TaskFlexibility.needsAgreement,
                  child: Text('Needs agreement'.tr),
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
                decoration: InputDecoration(labelText: 'Status'.tr),
                items: [
                  DropdownMenuItem(
                    value: TaskStatus.planned,
                    child: Text('Planned'.tr),
                  ),
                  DropdownMenuItem(
                    value: TaskStatus.completed,
                    child: Text('Completed'.tr),
                  ),
                  DropdownMenuItem(
                    value: TaskStatus.cancelled,
                    child: Text('Cancelled'.tr),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
            ],
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text('Protected task'.tr),
              value: _isProtected,
              onChanged: (value) => setState(() => _isProtected = value),
            ),
            if (_isProtected)
              DropdownButtonFormField<String?>(
                initialValue: _protectedCommitmentType,
                decoration: InputDecoration(
                  labelText: 'Protected commitment type'.tr,
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('Other protected task'.tr),
                  ),
                  DropdownMenuItem(
                    value: 'work_shift',
                    child: Text('Work shift'.tr),
                  ),
                  DropdownMenuItem(
                    value: 'family_duty',
                    child: Text('Family duty'.tr),
                  ),
                  DropdownMenuItem(
                    value: 'sleep_minimum',
                    child: Text('Sleep minimum'.tr),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _protectedCommitmentType = value),
              ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text('Optional task'.tr),
              value: _isOptional,
              onChanged: (value) => setState(() => _isOptional = value),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text('Schedule work time'.tr),
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
                tileColor: BalanceColors.surfaceSunken,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text('Planned start'.tr),
                subtitle: Text(
                  _scheduledStart == null
                      ? 'Choose date and time'.tr
                      : DateFormat.yMMMd().add_jm().format(_scheduledStart!),
                ),
                trailing: const Icon(Icons.schedule),
                onTap: _pickScheduledStart,
              ),
              if (_scheduledStart != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ends ${DateFormat.yMMMd().add_jm().format(_scheduledStart!.add(Duration(minutes: _scheduledMinutes)))}'
                      .tr,
                ),
              ],
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submit,
              child: Text(_isEditing ? 'Save changes'.tr : 'Create task'.tr),
            ),
          ],
        ),
      ),
    ),
  );

  /// Explains each category so students pick one on purpose.
  /// The app never guesses a category from the task title.
  static String _categoryHelp(LoadCategory? category) => switch (category) {
    null =>
      ('Study: coursework, revision · Errand: admin, chores, shopping · '
              'Social: meetups · Exercise: sport · Other: anything else')
          .tr,
    LoadCategory.study =>
      'Coursework, homework, revision and academic projects.'.tr,
    LoadCategory.errand =>
      'Admin, purchases, household jobs and other practical tasks.'.tr,
    LoadCategory.social => 'A planned meeting or social commitment.'.tr,
    LoadCategory.exercise => 'A planned sport or movement session.'.tr,
    LoadCategory.other => 'Anything that does not fit the other categories.'.tr,
  };

  Future<void> _pickDueAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: _dueAt.isBefore(DateTime.now()) ? _dueAt : DateTime.now(),
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
        SnackBar(
          content: Text(
            'The duration cannot be less than already allocated work. Review the plan first.'
                .tr,
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
        SnackBar(
          content: Text('Planned work must end before the task deadline.'.tr),
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
