import 'package:flutter/material.dart';

import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/app_theme.dart';

class CapacityGapCard extends StatelessWidget {
  const CapacityGapCard({super.key, required this.overloadMinutes});
  final int overloadMinutes;

  @override
  Widget build(BuildContext context) {
    final over = overloadMinutes > 0;
    final tone = over ? RpgTone.danger : RpgTone.calm;
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
                  over ? 'Capacity gap' : 'Plan is balanced',
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
                      ? '$overloadMinutes minutes must be moved, reduced or recovered.'
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
