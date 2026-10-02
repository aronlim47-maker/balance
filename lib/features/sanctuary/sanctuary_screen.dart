import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/shared_widgets/balance_scaffold.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../domain/models/recovery_slot.dart';
import 'sanctuary_view_model.dart';

class SanctuaryScreen extends StatelessWidget {
  const SanctuaryScreen({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => SanctuaryViewModel(context.read<RecoveryRepository?>())..load(),
    child: const _RecoveryContent(),
  );
}

class _RecoveryContent extends StatelessWidget {
  const _RecoveryContent();
  @override
  Widget build(BuildContext context) {
    final model = context.watch<SanctuaryViewModel>();
    return BalanceScaffold(
      title: 'Sanctuary', currentIndex: 3,
      actions: [IconButton(tooltip: 'Add recovery time',
        onPressed: model.busy || model.repository == null ? null : () => _edit(context, model),
        icon: const Icon(Icons.add))],
      body: RefreshIndicator(onRefresh: model.load, child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Recovery time', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          const Text('Keep time free. Resting needs no proof or activity.'),
          if (model.repository == null) const Card(child: Padding(
            padding: EdgeInsets.all(16), child: Text('Connect your account to protect recovery time.'))),
          if (model.busy) const LinearProgressIndicator(),
          if (model.error != null) Card(child: Padding(
            padding: const EdgeInsets.all(16), child: Column(children: [
              Text(model.error!), TextButton(onPressed: model.busy ? null : model.load,
                child: const Text('Try again')),
            ]))),
          if (!model.busy && model.error == null && model.slots.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No recovery time yet. Add a slot inside your availability.')),
          for (final slot in model.slots) Card(child: ListTile(
            leading: Icon(slot.isProtected ? Icons.shield_outlined : Icons.spa_outlined),
            title: Text(slot.selectedActivity ?? 'Unplanned rest'),
            subtitle: Text('${DateFormat('MMM d, h:mm a').format(slot.startAt.toLocal())} – '
              '${DateFormat('MMM d, h:mm a').format(slot.endAt.toLocal())}'
              '${slot.planChangeId != null ? '\nProtected by Council plan' : ''}'),
            trailing: slot.planChangeId != null ? const Icon(Icons.lock_outline) :
              PopupMenuButton<String>(enabled: !model.busy,
                onSelected: (value) async {
                  if (value == 'edit') { await _edit(context, model, slot); }
                  else {
                    final confirmed = await showDialog<bool>(context: context,
                      builder: (ctx) => AlertDialog(title: const Text('Remove recovery time?'),
                        content: const Text('This removes its protection from your plan.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove'))]));
                    if (confirmed == true) await model.remove(slot);
                  }
                }, itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Remove')),
                ]),
          )),
        ],
      )),
    );
  }

  Future<void> _edit(BuildContext context, SanctuaryViewModel model, [RecoverySlot? slot]) async {
    final result = await showDialog<RecoverySlot>(context: context,
      builder: (_) => _RecoveryForm(slot: slot));
    if (result != null) await model.save(result);
  }
}

class _RecoveryForm extends StatefulWidget {
  const _RecoveryForm({this.slot});
  final RecoverySlot? slot;
  @override
  State<_RecoveryForm> createState() => _RecoveryFormState();
}

class _RecoveryFormState extends State<_RecoveryForm> {
  late DateTime start = widget.slot?.startAt.toLocal() ?? DateTime.now();
  late DateTime end = widget.slot?.endAt.toLocal() ?? start.add(const Duration(minutes: 30));
  late final TextEditingController activity = TextEditingController(text: widget.slot?.selectedActivity);
  String? error;
  @override
  void dispose() { activity.dispose(); super.dispose(); }
  Future<void> pick(bool isStart) async {
    final current = isStart ? start : end;
    final date = await showDatePicker(context: context, initialDate: current,
      firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) { start = value; } else { end = value; }
    });
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.slot == null ? 'Protect recovery time' : 'Edit recovery time'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: const Text('Start'), subtitle: Text(DateFormat('MMM d, h:mm a').format(start)), onTap: () => pick(true)),
      ListTile(title: const Text('End'), subtitle: Text(DateFormat('MMM d, h:mm a').format(end)), onTap: () => pick(false)),
      TextField(controller: activity, maxLength: 80,
        decoration: const InputDecoration(labelText: 'Activity (optional)', hintText: 'Leave free for rest')),
      const Text('Must fit available time without overlapping planned work.'),
      if (error != null) Text(error!),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (end.difference(start).inMinutes < 1) {
          setState(() => error = 'End must be after start.'); return;
        }
        Navigator.pop(context, RecoverySlot(id: widget.slot?.id ?? '', startAt: start,
          endAt: end, selectedActivity: activity.text.trim().isEmpty ? null : activity.text.trim(),
          completedAt: widget.slot?.completedAt));
      }, child: const Text('Save'))],
  );
}
