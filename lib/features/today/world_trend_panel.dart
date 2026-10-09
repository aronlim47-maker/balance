import 'package:flutter/material.dart';

import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/balance_colors.dart';
import '../../domain/models/local_date.dart';
import '../../domain/models/world_trend_models.dart';
import '../../domain/usecases/world_trend_calculator.dart';

/// Seven-day cumulative workload trend (Rev7 14.4.1 WL05).
///
/// It shows the period, the unit, one bar per local date and the data gaps.
/// A date without a recorded total is shown as "No data": it is left out of the
/// average and is never drawn as zero or as an improving trend. Only a real
/// recorded total of 0 is drawn as 0.
class WorldTrendPanel extends StatelessWidget {
  const WorldTrendPanel({
    super.key,
    required this.selectedDay,
    required this.previousTotals,
    required this.todayTotal,
    this.todayIsPartial = false,
  });

  /// The selected local date; the window is the seven dates ending on it.
  final DateTime selectedDay;

  /// Totals for the seven dates before [selectedDay], oldest first
  /// (`null` = no snapshot for that date). Any other length counts as no data.
  final List<int?> previousTotals;

  /// The selected day's total, or `null` when it cannot be calculated yet.
  final int? todayTotal;
  final bool todayIsPartial;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _date(LocalDate d) => '${d.value.day} ${_months[d.value.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final end = LocalDate(selectedDay.year, selectedDay.month, selectedDay.day);
    final previous = previousTotals.length == 7
        ? previousTotals
        : List<int?>.filled(7, null);

    // Window date k (0 = oldest, 6 = selected day) <-> previous[k + 1].
    final values = <int?>[for (var k = 0; k < 6; k++) previous[k + 1], todayTotal];
    final history = <DailyWorldStatus>[
      for (var i = 0; i < 7; i++)
        if (previous[i] != null)
          DailyWorldStatus(
            localDate: end.addDays(i - 7),
            total: DimensionReading.known(previous[i]!.clamp(0, 100).toDouble()),
          ),
      if (todayTotal != null)
        DailyWorldStatus(
          localDate: end,
          total: todayIsPartial
              ? DimensionReading.partial(todayTotal!.clamp(0, 100).toDouble())
              : DimensionReading.known(todayTotal!.clamp(0, 100).toDouble()),
        ),
    ];
    final report = const WorldTrendCalculator().calculate7DayTrend(
      history,
      asOf: end,
    );
    final trend = report.total;
    final gaps = trend.unknownDays;

    final String summary;
    if (trend.observedDays == 0) {
      summary = 'No data in this period. Add availability and tasks to build a trend.';
    } else {
      summary =
          'Cumulative load: ${trend.cumulativeLoad!.round()} points over '
          '${trend.observedDays} of 7 days · average ${trend.movingAverage!.round()}';
    }

    return RpgPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelHeader('7-day workload trend'),
          const SizedBox(height: 4),
          Text(
            '${_date(report.windowStart)} – ${_date(report.windowEnd)} · '
            'score 0–100, higher means more planning pressure',
            style: const TextStyle(fontSize: 12, color: BalanceColors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var k = 0; k < 7; k++)
                Expanded(
                  child: _DayBar(
                    label: _weekdays[report.windowStart.addDays(k).value.weekday - 1],
                    value: values[k],
                    isToday: k == 6,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(summary, style: const TextStyle(fontSize: 13)),
          if (trend.observedDays > 0 && gaps > 0) ...[
            const SizedBox(height: 4),
            Text(
              gaps == 1
                  ? '1 day has no data and is left out of the average.'
                  : '$gaps days have no data and are left out of the average.',
              style: const TextStyle(fontSize: 12, color: BalanceColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.label, required this.value, required this.isToday});

  final String label;
  final int? value;
  final bool isToday;

  static const _maxHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final score = value;
    final height = score == null ? 0.0 : (score / 100 * _maxHeight).clamp(2.0, _maxHeight);
    return Semantics(
      label: '$label${isToday ? ' (selected day)' : ''}: '
          '${score == null ? 'no data' : '$score out of 100'}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _maxHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: score == null
                  ? const Text('—', style: TextStyle(color: BalanceColors.textMuted))
                  : Container(
                      width: 14,
                      height: height,
                      color: isToday ? BalanceColors.accentBright : BalanceColors.accent,
                    ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              score == null ? 'No data' : '$score',
              style: const TextStyle(fontSize: 10),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isToday ? BalanceColors.accentBright : BalanceColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
