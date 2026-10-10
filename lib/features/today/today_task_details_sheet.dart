import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/enums/task_flexibility.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/models/task_item.dart';
import '../../domain/models/plan_reservation.dart';

class TodayTaskDetailsSheet extends StatelessWidget {
  const TodayTaskDetailsSheet({
    super.key,
    required this.task,
    this.reservations = const [],
    this.explainDay = true,
    this.onEdit,
  });

  final TaskItem task;
  final List<PlanReservation> reservations;

  /// Today explains why the task counts on the viewed day; Quest Board does not.
  final bool explainDay;

  /// When given, an Edit button replaces the "edit in Quest Board" hint.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheduled = task.scheduledStart != null && task.scheduledEnd != null;
    final due = DateFormat.yMMMd().add_jm().format(task.dueAt.toLocal());
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            _Detail(
              label: 'Remaining',
              value: '${task.effectiveRemainingMinutes} min',
            ),
            _Detail(label: 'Due', value: due),
            for (final reservation in reservations)
              _Detail(
                label: 'Council slot',
                value:
                    '${DateFormat.MMMd().add_jm().format(reservation.startAt.toLocal())} – ${DateFormat.MMMd().add_jm().format(reservation.endAt.toLocal())}',
              ),
            if (scheduled)
              _Detail(
                label: 'Scheduled',
                value:
                    '${DateFormat.MMMd().add_jm().format(task.scheduledStart!.toLocal())} – ${DateFormat.jm().format(task.scheduledEnd!.toLocal())}',
              ),
            _Detail(
              label: 'Category',
              value: task.loadCategory?.label ?? 'Needs Review',
            ),
            _Detail(
              label: 'Flexibility',
              value: switch (task.flexibility) {
                TaskFlexibility.flexible => 'Flexible',
                TaskFlexibility.fixed => 'Fixed',
                TaskFlexibility.needsAgreement => 'Needs agreement',
              },
            ),
            if (task.isProtected)
              const _Detail(label: 'Protection', value: 'Protected'),
            if (task.isOptional)
              const _Detail(label: 'Priority', value: 'Optional'),
            _Detail(
              label: 'Status',
              value: switch (task.status) {
                TaskStatus.planned => 'Planned',
                TaskStatus.completed => 'Done',
                TaskStatus.cancelled => 'Cancelled',
              },
            ),
            if (explainDay) ...[
              const SizedBox(height: 14),
              Text(
                'Why is it here?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                reservations.isNotEmpty
                    ? 'Council moved part of this task here. Its reserved time counts toward this day’s capacity.'
                    : scheduled
                    ? 'Scheduled work overlaps this day and counts toward its capacity.'
                    : 'Due on this day. Remaining work counts toward capacity, but no time slot is reserved.',
              ),
            ],
            const SizedBox(height: 16),
            if (onEdit != null)
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit task'),
              )
            else
              const Text('Review or edit this task in Quest Board.'),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
