import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/shared_widgets/balance_scaffold.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../domain/models/recovery_slot.dart';
import 'recovery_slot_card.dart';
import 'sanctuary_view_model.dart';

/// Optional recovery ideas. Sanctuary is support, not therapy.
const recoverySuggestions = <String>[
  'Short walk',
  'Phone-free rest',
  'Sleep preparation',
  'Grounding exercise',
  'Reflection prompt',
  'Visit a campus support service',
];

class SanctuaryScreen extends StatelessWidget {
  const SanctuaryScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
    SanctuaryViewModel(context.read<RecoveryRepository?>())..load(),
    child: const _RecoveryContent(),
  );
}

class _RecoveryContent extends StatelessWidget {
  const _RecoveryContent();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SanctuaryViewModel>();
    final canEdit = !model.busy && model.repository != null;
    return BalanceScaffold(
      title: 'Sanctuary',
      currentIndex: 3,
      actions: [
        IconButton(
          tooltip: 'Add recovery time',
          onPressed: canEdit ? () => _edit(context, model) : null,
          icon: const Icon(Icons.add),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: model.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Recovery time',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep some time free. An activity is optional, and you can '
                  'skip it without any penalty. Marking an activity done does '
                  'not change your workload scores.',
            ),
            const SizedBox(height: 4),
            Text(
              'Sanctuary offers ideas for rest. It is not a medical or '
                  'therapy service.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (model.repository == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Sign in to protect recovery time.'),
                ),
              ),
            if (model.busy)
              const LinearProgressIndicator(
                semanticsLabel: 'Loading recovery time',
              ),
            if (model.error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(model.error!)),
                        ],
                      ),
                      TextButton(
                        onPressed: model.busy ? null : model.load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            if (!model.busy &&
                model.error == null &&
                model.repository != null &&
                model.slots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.spa_outlined, size: 48),
                    const SizedBox(height: 8),
                    const Text(
                      'No recovery time yet.',
                      textAlign: TextAlign.center,
                    ),
                    const Text(
                      'Add a slot inside your available time, or confirm a '
                          'Council plan that frees time.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: canEdit ? () => _edit(context, model) : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Add recovery time'),
                    ),
                  ],
                ),
              ),
            for (final slot in model.slots)
              RecoverySlotCard(
                slot: slot,
                busy: model.busy,
                onEdit: () => _edit(context, model, slot),
                onRemove: () => _remove(context, model, slot),
                onDoneChanged: (done) => _setDone(context, model, slot, done),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
      BuildContext context,
      SanctuaryViewModel model, [
        RecoverySlot? slot,
      ]) async {
    final result = await showDialog<RecoverySlot>(
      context: context,
      builder: (_) => _RecoveryForm(slot: slot),
    );
    if (result == null || !context.mounted) return;
    final saved = await model.save(result);
    if (saved && context.mounted) {
      _snack(context, slot == null ? 'Recovery time added.' : 'Recovery time updated.');
    }
  }

  Future<void> _remove(
      BuildContext context,
      SanctuaryViewModel model,
      RecoverySlot slot,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove recovery time?'),
        content: const Text('This removes its protection from your plan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final removed = await model.remove(slot);
    if (removed && context.mounted) _snack(context, 'Recovery time removed.');
  }

  Future<void> _setDone(
      BuildContext context,
      SanctuaryViewModel model,
      RecoverySlot slot,
      bool done,
      ) async {
    final saved = await model.setActivityDone(slot, done: done);
    if (saved && context.mounted) {
      _snack(context, done ? 'Activity marked done.' : 'Activity no longer marked done.');
    }
  }

  void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _RecoveryForm extends StatefulWidget {
  const _RecoveryForm({this.slot});
  final RecoverySlot? slot;

  @override
  State<_RecoveryForm> createState() => _RecoveryFormState();
}

class _RecoveryFormState extends State<_RecoveryForm> {
  static const _skip = '__skip__';
  static const _custom = '__custom__';

  late DateTime start = widget.slot?.startAt.toLocal() ?? _nextQuarterHour();
  late DateTime end =
      widget.slot?.endAt.toLocal() ?? start.add(const Duration(minutes: 30));
  late final TextEditingController customActivity;
  late String choice;
  String? error;

  @override
  void initState() {
    super.initState();
    final current = widget.slot?.selectedActivity;
    if (current == null) {
      choice = _skip;
      customActivity = TextEditingController();
    } else if (recoverySuggestions.contains(current)) {
      choice = current;
      customActivity = TextEditingController();
    } else {
      choice = _custom;
      customActivity = TextEditingController(text: current);
    }
  }

  static DateTime _nextQuarterHour() {
    final now = DateTime.now();
    final minutes = (now.minute ~/ 15 + 1) * 15;
    return DateTime(now.year, now.month, now.day, now.hour).add(
      Duration(minutes: minutes),
    );
  }

  @override
  void dispose() {
    customActivity.dispose();
    super.dispose();
  }

  Future<void> pick(bool isStart) async {
    final current = isStart ? start : end;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (isStart) {
        final length = end.difference(start);
        start = value;
        if (!end.isAfter(start)) end = start.add(length);
      } else {
        end = value;
      }
      error = null;
    });
  }

  String? get _activity => switch (choice) {
    _skip => null,
    _custom =>
    customActivity.text.trim().isEmpty ? null : customActivity.text.trim(),
    _ => choice,
  };

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('EEE, MMM d · h:mm a');
    return AlertDialog(
      title: Text(
        widget.slot == null ? 'Protect recovery time' : 'Edit recovery time',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start'),
              subtitle: Text(format.format(start)),
              trailing: const Icon(Icons.schedule),
              onTap: () => pick(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End'),
              subtitle: Text(format.format(end)),
              trailing: const Icon(Icons.schedule),
              onTap: () => pick(false),
            ),
            Text(
              'Must fit inside your available time without overlapping '
                  'planned work.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Activity (optional)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Skip for now'),
                  selected: choice == _skip,
                  onSelected: (_) => setState(() => choice = _skip),
                ),
                for (final suggestion in recoverySuggestions)
                  ChoiceChip(
                    label: Text(suggestion),
                    selected: choice == suggestion,
                    onSelected: (_) => setState(() => choice = suggestion),
                  ),
                ChoiceChip(
                  label: const Text('Something else'),
                  selected: choice == _custom,
                  onSelected: (_) => setState(() => choice = _custom),
                ),
              ],
            ),
            if (choice == _custom)
              TextField(
                controller: customActivity,
                maxLength: 80,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Your activity',
                  hintText: 'For example: listen to music',
                ),
              ),
            if (choice == _skip)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No problem. The time stays free for rest.'),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  void _submit() {
    if (end.difference(start).inMinutes < 1) {
      setState(() => error = 'End must be after start.');
      return;
    }
    if (choice == _custom && customActivity.text.trim().isEmpty) {
      setState(
            () => error = 'Type your activity, or choose Skip for now.',
      );
      return;
    }
    Navigator.pop(
      context,
      RecoverySlot(
        id: widget.slot?.id ?? '',
        startAt: start,
        endAt: end,
        selectedActivity: _activity,
        // A new or different activity has not been done yet.
        completedAt: _activity == widget.slot?.selectedActivity
            ? widget.slot?.completedAt
            : null,
      ),
    );
  }
}
