import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/enums/task_flexibility.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/models/task_item.dart';
import '../../domain/models/plan_reservation.dart';
import '../../core/l10n/tr.dart';

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
              label: 'Remaining'.tr,
              value: '${task.effectiveRemainingMinutes} min'.tr,
            ),
            _Detail(label: 'Due'.tr, value: due),
            for (final reservation in reservations)
              _Detail(
                label: 'Council slot'.tr,
                value:
                    '${DateFormat.MMMd().add_jm().format(reservation.startAt.toLocal())} – ${DateFormat.MMMd().add_jm().format(reservation.endAt.toLocal())}',
              ),
            if (scheduled)
              _Detail(
                label: 'Scheduled'.tr,
                value:
                    '${DateFormat.MMMd().add_jm().format(task.scheduledStart!.toLocal())} – ${DateFormat.jm().format(task.scheduledEnd!.toLocal())}',
              ),
            _Detail(
              label: 'Category'.tr,
              value: task.loadCategory?.label ?? 'Needs Review'.tr,
            ),
            _Detail(
              label: 'Flexibility'.tr,
              value: switch (task.flexibility) {
                TaskFlexibility.flexible => 'Flexible'.tr,
                TaskFlexibility.fixed => 'Fixed'.tr,
                TaskFlexibility.needsAgreement => 'Needs agreement'.tr,
              },
            ),
            if (task.isProtected)
              _Detail(label: 'Protection'.tr, value: 'Protected'.tr),
            if (task.isOptional)
              _Detail(label: 'Priority'.tr, value: 'Optional'.tr),
            _Detail(
              label: 'Status'.tr,
              value: switch (task.status) {
                TaskStatus.planned => 'Planned'.tr,
                TaskStatus.completed => 'Done'.tr,
                TaskStatus.cancelled => 'Cancelled'.tr,
              },
            ),
            if (explainDay) ...[
              const SizedBox(height: 14),
              Text(
                'Why is it here?'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                reservations.isNotEmpty
                    ? 'Council moved part of this task here. Its reserved time counts toward this day’s capacity.'
                          .tr
                    : scheduled
                    ? 'Scheduled work overlaps this day and counts toward its capacity.'
                          .tr
                    : 'Due on this day. Remaining work counts toward capacity, but no time slot is reserved.'
                          .tr,
              ),
            ],
            const SizedBox(height: 16),
            if (onEdit != null)
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: Text('Edit task'.tr),
              )
            else
              Text('Review or edit this task in Quest Board.'.tr),
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
