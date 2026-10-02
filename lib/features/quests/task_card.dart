import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${task.effectiveRemainingMinutes} min · '
                      'Due ${DateFormat.yMMMd().add_jm().format(task.dueAt.toLocal())}',
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    task.loadCategory?.label ?? 'Uncategorized · Needs Review',
                    _label(task.flexibility.name),
                    _label(task.status.name),
                    if (task.isProtected) 'Protected',
                    if (task.isOptional) 'Optional',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
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
    ),
  );

  String _label(String value) => value
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .trim()
      .split(' ')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
