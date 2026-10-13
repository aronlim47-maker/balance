import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/balance_colors.dart';
import '../../domain/usecases/explain_no_feasible_plan.dart';
import '../../domain/usecases/suggest_free_time.dart';

/// Explains, in plain language, why Council has no safe move and what the
/// student can do next. The buttons only navigate; nothing is changed here.
class NoPlanExplanationCard extends StatelessWidget {
  const NoPlanExplanationCard({
    super.key,
    required this.explanation,
    required this.onOpenTasks,
    required this.onOpenToday,
    this.freeTime,
    this.onEditTask,
    this.onAddFreeTimeOn,
  });

  final NoPlanExplanation explanation;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenToday;

  /// Extra free time that would unlock a plan, when Council found one.
  final FreeTimeSuggestion? freeTime;

  /// Opens the task editor for a task named in a reason.
  final ValueChanged<String>? onEditTask;

  /// Opens Today on the given day to add free time there.
  final ValueChanged<DateTime>? onAddFreeTimeOn;

  static const _editableKinds = {
    NoPlanReasonKind.noOtherDay,
    NoPlanReasonKind.needsAgreement,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return RpgPanel(
      tone: RpgTone.warning,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'No safe move found',
                style: textTheme.titleMedium?.copyWith(
                  color: BalanceColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Council keeps fixed and protected work in place and only moves '
              'flexible work, whole or in part, to free time before its '
              'deadline.',
              style: TextStyle(color: BalanceColors.textMuted),
            ),
            const SizedBox(height: 14),
            const RpgLabel('Why', size: 12),
            const SizedBox(height: 6),
            for (final reason in explanation.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 8),
                      child: Icon(
                        _icon(reason.kind),
                        size: 18,
                        color: reason.kind == NoPlanReasonKind.protectedStays
                            ? BalanceColors.calm
                            : BalanceColors.warning,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reason.message),
                          if (reason.taskId != null &&
                              onEditTask != null &&
                              _editableKinds.contains(reason.kind))
                            TextButton.icon(
                              onPressed: () => onEditTask!(reason.taskId!),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit task'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (explanation.suggestsTasks ||
                explanation.suggestsFreeTime ||
                freeTime != null) ...[
              const SizedBox(height: 6),
              const RpgLabel('What you can do', size: 12),
              const SizedBox(height: 8),
              if (freeTime != null) ...[
                _FreeTimeHint(suggestion: freeTime!),
                const SizedBox(height: 8),
                if (onAddFreeTimeOn != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => onAddFreeTimeOn!(freeTime!.day),
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(
                        'Add free time on '
                        '${DateFormat('EEE d MMM').format(freeTime!.day)}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (explanation.suggestsTasks)
                    OutlinedButton.icon(
                      onPressed: onOpenTasks,
                      icon: const Icon(Icons.notes_rounded),
                      label: const Text('Review tasks'),
                    ),
                  if (explanation.suggestsFreeTime &&
                      (freeTime == null || onAddFreeTimeOn == null))
                    OutlinedButton.icon(
                      onPressed: onOpenToday,
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Add free time on Today'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Or keep your current plan. Nothing changes unless you confirm.',
              style: TextStyle(fontSize: 13, color: BalanceColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(NoPlanReasonKind kind) => switch (kind) {
    NoPlanReasonKind.dayPassed => Icons.history,
    NoPlanReasonKind.noFreeTime => Icons.event_busy_outlined,
    NoPlanReasonKind.dueBeforeFreeTime => Icons.schedule,
    NoPlanReasonKind.noOtherDay => Icons.event_note_outlined,
    NoPlanReasonKind.noLaterFreeTime => Icons.date_range_outlined,
    NoPlanReasonKind.needsAgreement => Icons.handshake_outlined,
    NoPlanReasonKind.protectedStays => Icons.shield_outlined,
  };
}

/// One concrete "what if": the free time that would give Council a safe move.
class _FreeTimeHint extends StatelessWidget {
  const _FreeTimeHint({required this.suggestion});

  final FreeTimeSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final day = DateFormat('EEE d MMM').format(suggestion.day);
    final from = DateFormat.jm().format(suggestion.start.toLocal());
    final to = DateFormat.jm().format(suggestion.end.toLocal());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 8),
          child: Icon(
            Icons.lightbulb_outline,
            size: 18,
            color: BalanceColors.gold,
          ),
        ),
        Expanded(
          child: Text(
            'Add ${_duration(suggestion.minutes)} of free time on $day '
            '(for example $from–$to) and Council can move '
            '"${suggestion.taskTitle}" there.'
            '${suggestion.dayAlreadyOverMinutes > 0 ? ' $day is already ${_duration(suggestion.dayAlreadyOverMinutes)} over, so this covers that too.' : ''}',
          ),
        ),
      ],
    );
  }

  static String _duration(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$rest min';
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }
}
