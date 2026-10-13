import 'package:flutter/material.dart';

import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/app_theme.dart';

class CapacityGapCard extends StatelessWidget {
  const CapacityGapCard({
    super.key,
    required this.overloadMinutes,
    this.plannedMinutes,
    this.availableMinutes,
  });
  final int overloadMinutes;

  /// When given, the card explains a gap larger than "planned − available"
  /// (work due before the free time starts) and treats an empty day as
  /// "nothing planned yet" rather than balanced.
  final int? plannedMinutes;
  final int? availableMinutes;

  String get _overText {
    final base =
        '$overloadMinutes minutes must be moved, reduced or recovered.';
    final planned = plannedMinutes, available = availableMinutes;
    if (planned == null || available == null) return base;
    final beyond = planned > available ? planned - available : 0;
    final dueEarly = overloadMinutes - beyond;
    if (dueEarly <= 0) return base;
    return beyond == 0
        ? '$base All of it is due before your free time starts.'
        : '$base $beyond min is beyond your free time and $dueEarly min is due '
              'before your free time starts.';
  }

  @override
  Widget build(BuildContext context) {
    final over = overloadMinutes > 0;
    final empty = !over && plannedMinutes == 0 && availableMinutes == 0;
    final tone = over
        ? RpgTone.danger
        : empty
        ? RpgTone.muted
        : RpgTone.calm;
    return RpgPanel(
      tone: tone,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: DiamondIcon(size: 16, color: tone.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  over
                      ? 'Capacity gap'
                      : empty
                      ? 'Nothing planned yet'
                      : 'Plan is balanced',
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 1.6,
                    color: tone.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  over
                      ? _overText
                      : empty
                      ? 'Add your free time and tasks to see if this day fits.'
                      : 'Planned work fits within your available time.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
