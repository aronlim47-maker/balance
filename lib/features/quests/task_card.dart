import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/balance_colors.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/models/task_item.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
    this.onStatusChange,
    this.isOverdue = false,
    this.onTap,
  });

  final TaskItem task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Called with completed (Mark as done) or planned (Mark as not done).
  final ValueChanged<TaskStatus>? onStatusChange;

  /// Display only. The label is text, not colour alone, for screen readers.
  final bool isOverdue;

  /// Opens the task's details.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final protectedTask = task.isProtected;
    final done = task.status != TaskStatus.planned;
    final minutes = task.effectiveRemainingMinutes;
    final due = task.dueAt.toLocal();
    // Short date: the year only appears when it is not this year.
    final dueText = DateFormat(
      due.year == DateTime.now().year
          ? 'EEE d MMM, h:mm a'
          : 'EEE d MMM y, h:mm a',
    ).format(due);
    final PopupMenuItem<String> statusAction = switch (task.status) {
      TaskStatus.planned => const PopupMenuItem(
        value: 'done',
        child: Text('Mark as done'),
      ),
      TaskStatus.completed => const PopupMenuItem(
        value: 'undone',
        child: Text('Mark as not done'),
      ),
      TaskStatus.cancelled => const PopupMenuItem(
        value: 'undone',
        child: Text('Restore task'),
      ),
    };
    return RpgPanel(
      onTap: onTap,
      tone: protectedTask
          ? RpgTone.calm
          : isOverdue
          ? RpgTone.warning
          : RpgTone.muted,
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 12),
            child: protectedTask
                ? const Icon(
                    Icons.shield_outlined,
                    size: 20,
                    color: BalanceColors.calm,
                    semanticLabel: 'Protected',
                  )
                : DiamondIcon(
                    size: 16,
                    filled: done,
                    color: done
                        ? BalanceColors.textFaint
                        : BalanceColors.accentBright,
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: 0.8,
                    height: 1.15,
                    color: done ? BalanceColors.textMuted : BalanceColors.text,
                    decoration: task.status == TaskStatus.cancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOverdue
                      ? '$minutes min · Was due $dueText'
                      : '$minutes min · Due $dueText',
                  style: TextStyle(
                    color: isOverdue
                        ? BalanceColors.warning
                        : BalanceColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (isOverdue)
                      const RpgTag(
                        'Overdue',
                        tone: RpgTone.warning,
                        icon: Icons.schedule,
                      ),
                    if (task.isProtected)
                      const RpgTag(
                        'Protected',
                        tone: RpgTone.calm,
                        icon: Icons.shield_outlined,
                      ),
                    RpgTag(
                      task.loadCategory?.label ??
                          'Uncategorized · Needs Review',
                      tone: task.loadCategory == null
                          ? RpgTone.warning
                          : RpgTone.accent,
                    ),
                    RpgTag(_label(task.flexibility.name)),
                    if (task.status != TaskStatus.planned)
                      RpgTag(_label(task.status.name), tone: RpgTone.muted),
                    if (task.isOptional) const RpgTag('Optional'),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Task actions',
            onSelected: (value) {
              if (value == 'done') onStatusChange?.call(TaskStatus.completed);
              if (value == 'undone') onStatusChange?.call(TaskStatus.planned);
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              if (onStatusChange != null) statusAction,
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  String _label(String value) => value
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .trim()
      .split(' ')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
