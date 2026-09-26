import 'package:flutter/material.dart';

class CapacityGapCard extends StatelessWidget {
  const CapacityGapCard({super.key, required this.overloadMinutes});
  final int overloadMinutes;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            overloadMinutes > 0
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: overloadMinutes > 0
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overloadMinutes > 0 ? 'Capacity gap' : 'Plan is balanced',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  overloadMinutes > 0
                      ? '$overloadMinutes minutes must be moved, reduced or recovered.'
                      : 'Planned work fits within your available time.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
