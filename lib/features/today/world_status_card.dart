import 'package:flutter/material.dart';

class WorldStatusCard extends StatelessWidget {
  const WorldStatusCard({
    super.key,
    required this.plannedMinutes,
    required this.availableMinutes,
  });

  final int plannedMinutes;
  final int availableMinutes;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily capacity', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Metric(label: 'Planned', value: plannedMinutes),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(label: 'Available', value: availableMinutes),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 4),
      Text('$value min', style: Theme.of(context).textTheme.headlineSmall),
    ],
  );
}
