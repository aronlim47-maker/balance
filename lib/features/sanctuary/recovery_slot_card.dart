import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/balance_colors.dart';
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
    final start = slot.startAt.toLocal();
    final end = slot.endAt.toLocal();
    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final dayFormat = DateFormat('EEE, MMM d');
    final timeFormat = DateFormat('h:mm a');
    final timeText = sameDay
        ? '${dayFormat.format(start)} · ${timeFormat.format(start)} – ${timeFormat.format(end)}'
        : '${dayFormat.format(start)} ${timeFormat.format(start)} – '
              '${dayFormat.format(end)} ${timeFormat.format(end)}';
    final title = slot.selectedActivity ?? 'Free rest time';

    return RpgPanel(
      tone: slot.isProtected ? RpgTone.calm : RpgTone.muted,
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 12),
                child: Icon(
                  slot.isProtected ? Icons.shield_outlined : Icons.eco_outlined,
                  color: BalanceColors.calm,
                  size: 20,
                  semanticLabel: slot.isProtected
                      ? 'Protected time'
                      : 'Unprotected time',
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: 0.8,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeText,
                      style: const TextStyle(
                        color: BalanceColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (_fromCouncil)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: BalanceColors.textMuted,
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
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                const RpgTag(
                  'Time reserved',
                  tone: RpgTone.calm,
                  icon: Icons.event_available_outlined,
                ),
                if (_isDone)
                  const RpgTag(
                    'Activity done',
                    tone: RpgTone.accent,
                    icon: Icons.check,
                  ),
                if (_fromCouncil)
                  const RpgTag('From Council plan', icon: Icons.gavel_outlined),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 6),
            child: _fromCouncil
                ? const Text(
                    'This time was freed by a confirmed plan. '
                    'Undo the plan in Council to change it.',
                    style: TextStyle(
                      fontSize: 13,
                      color: BalanceColors.textMuted,
                    ),
                  )
                : slot.selectedActivity == null
                ? const Text(
                    'No activity planned. Rest needs no proof.',
                    style: TextStyle(
                      fontSize: 13,
                      color: BalanceColors.textMuted,
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: _isDone
                        ? TextButton.icon(
                            onPressed: busy ? null : () => onDoneChanged(false),
                            icon: const Icon(Icons.undo, size: 18),
                            label: const Text('Undo activity done'),
                          )
                        : TextButton.icon(
                            onPressed: busy || !_hasStarted
                                ? null
                                : () => onDoneChanged(true),
                            icon: const Icon(Icons.check, size: 18),
                            label: Text(
                              _hasStarted
                                  ? 'Mark activity done'
                                  : 'Mark done after it starts',
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
