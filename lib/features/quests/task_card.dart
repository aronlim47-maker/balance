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
  });

  final TaskItem task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final protectedTask = task.isProtected;
    final done = task.status != TaskStatus.planned;
    final minutes = task.effectiveRemainingMinutes;
    return RpgPanel(
      tone: protectedTask ? RpgTone.calm : RpgTone.muted,
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
                  '$minutes min · '
                  'Due ${DateFormat.yMMMd().add_jm().format(task.dueAt.toLocal())}',
                  style: const TextStyle(
                    color: BalanceColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (task.isProtected)
                      const RpgTag(
                        'Protected',
                        tone: RpgTone.calm,
                        icon: Icons.shield_outlined,
                      ),
                    RpgTag(
                      task.loadCategory?.label ?? 'Uncategorized · Needs Review',
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
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
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
