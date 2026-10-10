import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/shared_widgets/balance_scaffold.dart';
import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/balance_colors.dart';
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

  /// The slot happening now, or the next upcoming one.
  RecoverySlot? _featured(List<RecoverySlot> slots) {
    final now = DateTime.now();
    final upcoming = slots.where((slot) => slot.endAt.isAfter(now)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SanctuaryViewModel>();
    final canEdit = !model.busy && model.repository != null;
    final featured = _featured(model.slots);
    return BalanceScaffold(
      title: 'Sanctuary',
      headline: 'Recovery time',
      subtitle: 'Protected time for rest. Activities are optional.',
      eyebrowTone: RpgTone.calm,
      currentIndex: 3,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: RpgSquareButton(
            tooltip: 'Add recovery time',
            filled: true,
            onPressed: canEdit ? () => _edit(context, model) : null,
            icon: Icons.add,
          ),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: model.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (model.repository == null)
              const RpgPanel(
                tone: RpgTone.warning,
                child: Text('Sign in to protect recovery time.'),
              ),
            if (model.busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(
                  semanticsLabel: 'Loading recovery time',
                ),
              ),
            if (model.error != null) ...[
              RpgPanel(
                tone: RpgTone.danger,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: BalanceColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(model.error!)),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (model.needsAvailability)
                          FilledButton.icon(
                            onPressed: () => context.go(AppRoutes.today),
                            icon: const Icon(Icons.event_available_outlined),
                            label: const Text('Go to Today'),
                          ),
                        TextButton(
                          onPressed: model.busy ? null : model.load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (featured != null) ...[
              _FeaturedSlot(slot: featured),
              const SizedBox(height: 20),
            ],
            if (!model.busy &&
                model.error == null &&
                model.repository != null &&
                model.slots.isEmpty)
              RpgPanel(
                tone: RpgTone.calm,
                dashed: true,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.eco_outlined,
                      size: 40,
                      color: BalanceColors.calm,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No recovery time yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Add a slot inside your available time, or confirm a '
                      'Council plan that frees time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: BalanceColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: canEdit ? () => _edit(context, model) : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Add recovery time'),
                    ),
                  ],
                ),
              ),
            if (model.slots.isNotEmpty) ...[
              const SectionRule('All recovery slots', tone: RpgTone.calm),
              const SizedBox(height: 10),
              for (final slot in model.slots)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RecoverySlotCard(
                    slot: slot,
                    busy: model.busy,
                    onEdit: () => _edit(context, model, slot),
                    onRemove: () => _remove(context, model, slot),
                    onDoneChanged: (done) =>
                        _setDone(context, model, slot, done),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Skipping has no penalty, and rest does not change your scores. '
              'Not a medical or therapy service.',
              style: TextStyle(fontSize: 12, color: BalanceColors.textMuted),
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
      _snack(
        context,
        slot == null ? 'Recovery time added.' : 'Recovery time updated.',
      );
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
      _snack(
        context,
        done ? 'Activity marked done.' : 'Activity no longer marked done.',
      );
    }
  }

  void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}

/// Big green panel for the current or next slot: "TONIGHT · 21:30 – 22:15".
class _FeaturedSlot extends StatelessWidget {
  const _FeaturedSlot({required this.slot});
  final RecoverySlot slot;

  String _when(DateTime start) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(start.year, start.month, start.day);
    final diff = day.difference(today).inDays;
    if (!start.isAfter(now)) return 'Happening now';
    if (diff == 0) return start.hour >= 18 ? 'Tonight' : 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEEE d MMM').format(start);
  }

  @override
  Widget build(BuildContext context) {
    final start = slot.startAt.toLocal();
    final end = slot.endAt.toLocal();
    final minutes = end.difference(start).inMinutes;
    final time = DateFormat.Hm();
    return RpgPanel(
      tone: RpgTone.calm,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: RpgLabel(_when(start), tone: RpgTone.calm)),
              if (slot.isProtected)
                const RpgTag(
                  'Protected',
                  tone: RpgTone.calm,
                  icon: Icons.shield_outlined,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${time.format(start)} – ${time.format(end)}',
            style: const TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 34,
              letterSpacing: 1,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatShortDuration(minutes)} held clear. '
            'Nothing will be scheduled into it.',
            style: const TextStyle(color: BalanceColors.textMuted),
          ),
          if (slot.selectedActivity != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const DiamondIcon(
                  size: 12,
                  filled: true,
                  color: BalanceColors.calm,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slot.selectedActivity!,
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
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
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(Duration(minutes: minutes));
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

  Widget _timeTile(String label, DateTime value, VoidCallback onTap) =>
      RpgPanel(
        tone: RpgTone.muted,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 52, child: RpgLabel(label, size: 12)),
            Expanded(
              child: Text(
                DateFormat('EEE, MMM d · h:mm a').format(value),
                style: const TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const Icon(
              Icons.schedule,
              size: 18,
              color: BalanceColors.textMuted,
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.slot == null ? 'Protect recovery time' : 'Edit recovery time',
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: 'Start',
              child: _timeTile('Start', start, () => pick(true)),
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: 'End',
              child: _timeTile('End', end, () => pick(false)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Must fit inside your available time without overlapping '
              'planned work. Add availability on Today first if this day '
              'has none.',
              style: TextStyle(fontSize: 12, color: BalanceColors.textMuted),
            ),
            const SizedBox(height: 18),
            const SectionRule(
              'Something to do with it',
              subtitle: 'Optional · the slot holds either way',
              tone: RpgTone.calm,
            ),
            const SizedBox(height: 10),
            for (final suggestion in recoverySuggestions) ...[
              DiamondOptionRow(
                title: suggestion,
                selected: choice == suggestion,
                tone: RpgTone.calm,
                onTap: () => setState(() => choice = suggestion),
              ),
              const SizedBox(height: 8),
            ],
            DiamondOptionRow(
              title: 'Something else',
              selected: choice == _custom,
              tone: RpgTone.calm,
              onTap: () => setState(() => choice = _custom),
            ),
            if (choice == _custom) ...[
              const SizedBox(height: 8),
              TextField(
                controller: customActivity,
                maxLength: 80,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Your activity',
                  hintText: 'For example: listen to music',
                ),
              ),
            ],
            const SizedBox(height: 8),
            DiamondOptionRow(
              title: 'Skip for now',
              subtitle: choice == _skip
                  ? 'No problem. The time stays free for rest.'
                  : 'Leave it unplanned',
              selected: choice == _skip,
              dashed: true,
              tone: RpgTone.calm,
              onTap: () => setState(() => choice = _skip),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  error!,
                  style: const TextStyle(color: BalanceColors.danger),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(110, 48)),
        onPressed: _submit,
        child: const Text('Save'),
      ),
    ],
  );

  void _submit() {
    if (end.difference(start).inMinutes < 1) {
      setState(() => error = 'End must be after start.');
      return;
    }
    if (choice == _custom && customActivity.text.trim().isEmpty) {
      setState(() => error = 'Type your activity, or choose Skip for now.');
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
