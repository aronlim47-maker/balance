import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/recovery_slot.dart';

/// One recovery slot in Sanctuary.
///
/// Keeps two states visibly separate:
/// 1. the time is reserved (always true for a listed slot), and
/// 2. the optional activity was marked done (only if the user chose to).
/// Energy lives in the Today check-in and is never inferred here.
class RecoverySlotCard extends StatelessWidget {
  const RecoverySlotCard({
    super.key,
    required this.slot,
    required this.busy,
    required this.onEdit,
    required this.onRemove,
    required this.onDoneChanged,
  });

  final RecoverySlot slot;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final ValueChanged<bool> onDoneChanged;

  bool get _fromCouncil => slot.planChangeId != null;
  bool get _isDone => slot.completedAt != null;
  bool get _hasStarted => !DateTime.now().isBefore(slot.startAt);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = DateFormat('EEE, MMM d · h:mm a');
    final endFormat = DateFormat('h:mm a');
    final sameDay =
        slot.startAt.toLocal().day == slot.endAt.toLocal().day &&
            slot.startAt.toLocal().month == slot.endAt.toLocal().month;
    final timeText =
        '${format.format(slot.startAt.toLocal())} – '
        '${(sameDay ? endFormat : format).format(slot.endAt.toLocal())}';
    final title = slot.selectedActivity ?? 'Free rest time';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 12),
                  child: Icon(
                    slot.isProtected
                        ? Icons.shield_outlined
                        : Icons.spa_outlined,
                    semanticLabel: slot.isProtected
                        ? 'Protected time'
                        : 'Unprotected time',
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(timeText),
                    ],
                  ),
                ),
                if (_fromCouncil)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.lock_outline,
                      semanticLabel: 'Locked by a Council plan',
                    ),
                  )
                else
                  PopupMenuButton<String>(
                    tooltip: 'Recovery time actions',
                    enabled: !busy,
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'remove') onRemove();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                const Chip(
                  avatar: Icon(Icons.event_available_outlined, size: 18),
                  label: Text('Time reserved'),
                ),
                if (_isDone)
                  const Chip(
                    avatar: Icon(Icons.check_circle_outline, size: 18),
                    label: Text('Activity done'),
                  ),
                if (_fromCouncil)
                  const Chip(
                    avatar: Icon(Icons.gavel_outlined, size: 18),
                    label: Text('From Council plan'),
                  ),
              ],
            ),
            if (_fromCouncil)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'This time was freed by a confirmed plan. '
                      'Undo the plan in Council to change it.',
                ),
              )
            else if (slot.selectedActivity == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('No activity planned. Rest needs no proof.'),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: _isDone
                    ? TextButton.icon(
                  onPressed: busy ? null : () => onDoneChanged(false),
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo activity done'),
                )
                    : TextButton.icon(
                  onPressed: busy || !_hasStarted
                      ? null
                      : () => onDoneChanged(true),
                  icon: const Icon(Icons.check),
                  label: Text(
                    _hasStarted
                        ? 'Mark activity done'
                        : 'Mark done after it starts',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
