import 'package:flutter/material.dart';

import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/balance_colors.dart';
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
  Widget build(BuildContext context) {
    final overMinutes = plannedMinutes - availableMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CapacityPanel(
          plannedMinutes: plannedMinutes,
          availableMinutes: availableMinutes,
          overMinutes: overMinutes,
        ),
        const SizedBox(height: 12),
        RpgPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'World Status',
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                  Text(
                    status.totalScore == null
                        ? 'Not enough data'
                        : '${status.totalScore}/100 · ${status.label}',
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 1,
                      color: toneForScore(status.totalScore).foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                children: [
                  RpgLabel('Load', tone: RpgTone.neutral, size: 13),
                  SizedBox(width: 8),
                  Text(
                    'five dimensions',
                    style: TextStyle(
                      fontSize: 12,
                      color: BalanceColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 12),
              for (final dimension in WorldDimension.values) ...[
                _DimensionRow(
                  name: _name(dimension),
                  result: status.dimensions[dimension]!,
                ),
                if (dimension != WorldDimension.errands)
                  const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const RpgLabel('Calamity', tone: RpgTone.neutral, size: 13),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'workload trend',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: BalanceColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      switch (status.trend) {
                        WorldTrend.rising => 'Trend: Rising',
                        WorldTrend.easing => 'Trend: Easing',
                        WorldTrend.stable => 'Trend: Stable',
                        WorldTrend.notEnoughHistory =>
                        'Trend: Not enough history',
                      },
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.8,
                        color: switch (status.trend) {
                          WorldTrend.rising => BalanceColors.warning,
                          WorldTrend.easing => BalanceColors.calm,
                          WorldTrend.stable => BalanceColors.text,
                          WorldTrend.notEnoughHistory =>
                          BalanceColors.textMuted,
                        },
                      ),
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                title: const Text(
                  'How is this calculated?',
                  style: TextStyle(
                    color: BalanceColors.accentBright,
                    fontSize: 14,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      status.totalScore == null
                          ? 'A total appears when enough dimensions have recorded data.'
                          : '${(status.coverage * 100).round()}% data coverage${status.isPartial ? ' · Partial result' : ''}.',
                    ),
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
                    style: TextStyle(color: BalanceColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

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

/// "TIME CAPACITY · 3H AVAILABLE · 5H PLANNED" with a fits/beyond bar.
class _CapacityPanel extends StatelessWidget {
  const _CapacityPanel({
    required this.plannedMinutes,
    required this.availableMinutes,
    required this.overMinutes,
  });

  final int plannedMinutes;
  final int availableMinutes;
  final int overMinutes;

  @override
  Widget build(BuildContext context) {
    const segments = 10;
    final scale = plannedMinutes > availableMinutes
        ? plannedMinutes
        : availableMinutes;
    final fits = plannedMinutes < availableMinutes
        ? plannedMinutes
        : availableMinutes;
    final over = overMinutes > 0 ? overMinutes : 0;
    var fitSegments = scale == 0 ? 0 : (fits / scale * segments).round();
    var overSegments = scale == 0 ? 0 : (over / scale * segments).round();
    if (over > 0 && overSegments == 0) overSegments = 1;
    if (fitSegments + overSegments > segments) {
      fitSegments = segments - overSegments;
    }

    return RpgPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHeader(
            'Time capacity',
            trailing: over > 0
                ? RpgTag('${formatShortDuration(over)} over', tone: RpgTone.danger)
                : const RpgTag('Fits', tone: RpgTone.calm),
          ),
          const SizedBox(height: 12),
          Text(
            availableMinutes == 0 && plannedMinutes == 0
                ? 'NO TIME ADDED YET'
                : '${formatShortDuration(availableMinutes)} AVAILABLE · '
                '${formatShortDuration(plannedMinutes)} PLANNED',
            style: const TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 26,
              height: 1.15,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 14),
          SegmentMeter(
            total: segments,
            filled: fitSegments,
            over: overSegments,
            height: 10,
            gap: 3,
            semanticsLabel:
            '$plannedMinutes minutes planned, $availableMinutes minutes available',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _Legend(
                color: BalanceColors.accent,
                text: 'Fits today · ${formatShortDuration(fits)}',
              ),
              if (over > 0)
                _Legend(
                  color: BalanceColors.dangerFill,
                  text: 'Beyond capacity · ${formatShortDuration(over)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 9, height: 9, color: color),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(fontSize: 12, color: BalanceColors.textMuted),
      ),
    ],
  );
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({required this.name, required this.result});

  final String name;
  final DimensionResult result;

  @override
  Widget build(BuildContext context) {
    final score = result.score;
    final tone = toneForScore(score);
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            name,
            style: const TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 1.6,
            ),
          ),
        ),
        Expanded(
          child: score == null
              ? const SegmentMeter(filled: 0)
              : SegmentMeter.fromScore(
            score,
            semanticsLabel: '$name planning load $score',
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(
            score == null
                ? 'Unknown'
                : '$score/100${result.isPartial ? '*' : ''}',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.8,
              color: score == null ? BalanceColors.textFaint : tone.foreground,
            ),
          ),
        ),
      ],
    );
  }
}