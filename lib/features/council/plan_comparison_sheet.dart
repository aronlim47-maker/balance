import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/usecases/preview_trade_off.dart';

class PlanComparisonSheet extends StatelessWidget {
  const PlanComparisonSheet({
    super.key,
    required this.previews,
    this.confirmation = false,
  });
  final List<TradeOffPreview> previews;
  final bool confirmation;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: 0.85,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  confirmation ? 'Review before confirming' : 'Compare plans',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Rules-based preview. Nothing is saved here. Supabase checks again when you confirm.',
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var index = 0; index < previews.length; index++)
                _OptionPreview(
                  preview: previews[index],
                  index: index + 1,
                  confirmation: confirmation,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OptionPreview extends StatelessWidget {
  const _OptionPreview({
    required this.preview,
    required this.index,
    required this.confirmation,
  });
  final TradeOffPreview preview;
  final int index;
  final bool confirmation;

  @override
  Widget build(BuildContext context) {
    final option = preview.option;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Option $index · ${option.taskTitle}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Move ${option.movedMinutes} min across ${option.allMoves.length} task${option.allMoves.length == 1 ? '' : 's'}',
            ),
            for (final move in option.allMoves)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${move.taskTitle}: ${move.movedMinutes} min · '
                  '${DateFormat.MMMd().add_jm().format(move.proposedStart.toLocal())}–'
                  '${DateFormat.jm().format(move.proposedEnd.toLocal())}',
                ),
              ),
            const SizedBox(height: 12),
            for (final day in preview.days)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMd().format(day.day),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      'Planned: ${day.before.plannedMinutes} → ${day.after.plannedMinutes} min',
                    ),
                    Text(
                      'Available: ${day.after.availableMinutes} min · Gap: ${day.before.overloadMinutes} → ${day.after.overloadMinutes} min',
                    ),
                  ],
                ),
              ),
            const Text(
              'Trade-off: destination times take this work; total workload and deadlines do not decrease.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Protected tasks and recovery stay unchanged. No new recovery slot is reserved.',
            ),
            if (preview.protectedTitles.isNotEmpty)
              ExpansionTile(
                title: Text(
                  '${preview.protectedTitles.length} fixed/protected tasks unchanged',
                ),
                children: [
                  for (final title in preview.protectedTitles)
                    ListTile(title: Text(title)),
                ],
              ),
            if (preview.issue != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(preview.issue!),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: confirmation && !preview.canApply
                  ? null
                  : () => Navigator.pop(context, option.id),
              child: Text(
                confirmation
                    ? (option.allMoves.length == 1
                          ? 'Confirm this move'
                          : 'Confirm these moves')
                    : 'Select this option',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
