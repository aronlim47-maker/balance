import 'package:flutter/material.dart';

import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/balance_colors.dart';
import '../../domain/usecases/explain_no_feasible_plan.dart';

/// Explains, in plain language, why Council has no safe move and what the
/// student can do next. The buttons only navigate; nothing is changed here.
class NoPlanExplanationCard extends StatelessWidget {
  const NoPlanExplanationCard({
    super.key,
    required this.explanation,
    required this.onOpenTasks,
    required this.onOpenToday,
  });

  final NoPlanExplanation explanation;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenToday;

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
            const Text(
              'Council keeps protected work in place and only moves flexible '
              'work that already has a time.',
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
                    Expanded(child: Text(reason.message)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            const RpgLabel('What you can do', size: 12),
            const SizedBox(height: 8),
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
                if (explanation.suggestsFreeTime)
                  OutlinedButton.icon(
                    onPressed: onOpenToday,
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Add free time on Today'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Or keep your current plan. Nothing changes unless you confirm.',
              style: TextStyle(fontSize: 13, color: BalanceColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(NoPlanReasonKind kind) => switch (kind) {
    NoPlanReasonKind.noFreeTime => Icons.event_busy_outlined,
    NoPlanReasonKind.dueBeforeFreeTime => Icons.schedule,
    NoPlanReasonKind.flexibleUnscheduled => Icons.edit_calendar_outlined,
    NoPlanReasonKind.noLaterFreeTime => Icons.date_range_outlined,
    NoPlanReasonKind.needsAgreement => Icons.handshake_outlined,
    NoPlanReasonKind.protectedStays => Icons.shield_outlined,
  };
}
