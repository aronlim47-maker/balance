import 'package:flutter/material.dart';

import '../../domain/usecases/world_status_calculator.dart';

class WorldStatusCard extends StatelessWidget {
  const WorldStatusCard({
    super.key,
    required this.plannedMinutes,
    required this.availableMinutes,
    required this.status,
  });

  final int plannedMinutes;
  final int availableMinutes;
  final WorldStatusResult status;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'World Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                status.totalScore == null
                    ? 'Not enough data'
                    : '${status.totalScore}/100 · ${status.label}',
              ),
            ],
          ),
          const SizedBox(height: 14),
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
          const Divider(height: 24),
          for (final dimension in WorldDimension.values) ...[
            _DimensionRow(
              name: _name(dimension),
              result: status.dimensions[dimension]!,
            ),
            if (dimension != WorldDimension.errands) const SizedBox(height: 9),
          ],
          const SizedBox(height: 8),
          Text(switch (status.trend) {
            WorldTrend.rising => 'Trend: Rising',
            WorldTrend.easing => 'Trend: Easing',
            WorldTrend.stable => 'Trend: Stable',
            WorldTrend.notEnoughHistory => 'Trend: Not enough history',
          }, style: Theme.of(context).textTheme.bodySmall),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('How is this calculated?'),
            children: [
              Text(
                status.totalScore == null
                    ? 'A total appears when enough dimensions have recorded data.'
                    : '${(status.coverage * 100).round()}% data coverage${status.isPartial ? ' · Partial result' : ''}.',
              ),
              const SizedBox(height: 8),
              for (final dimension in WorldDimension.values) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_name(dimension)}: ${status.dimensions[dimension]!.reason ?? _source(dimension)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              const Text(
                'Unknown means missing information, not zero pressure. This is a planning aid, not a health assessment.',
              ),
            ],
          ),
        ],
      ),
    ),
  );

  static String _name(WorldDimension dimension) => switch (dimension) {
    WorldDimension.mental => 'Mental',
    WorldDimension.time => 'Time',
    WorldDimension.physical => 'Physical',
    WorldDimension.social => 'Social',
    WorldDimension.errands => 'Errands',
  };

  static String _source(WorldDimension dimension) => switch (dimension) {
    WorldDimension.mental => 'Tasks, capacity, Daily Review and recovery',
    WorldDimension.time => 'Availability, tasks, deadlines and recovery',
    WorldDimension.physical => 'Confirmed exercise and optional energy',
    WorldDimension.social => 'Confirmed events and schedule conflicts',
    WorldDimension.errands => 'User-categorised practical tasks',
  };
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({required this.name, required this.result});

  final String name;
  final DimensionResult result;

  @override
  Widget build(BuildContext context) {
    final score = result.score;
    return Row(
      children: [
        SizedBox(width: 72, child: Text(name)),
        Expanded(
          child: score == null
              ? const SizedBox.shrink()
              : LinearProgressIndicator(
                  value: score / 100,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(6),
                  semanticsLabel: '$name planning load',
                  semanticsValue: '$score',
                ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            score == null
                ? 'Unknown'
                : '$score/100${result.isPartial ? '*' : ''}',
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
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
