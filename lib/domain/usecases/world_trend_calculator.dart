import '../models/local_date.dart';
import '../models/world_trend_models.dart';
import 'world_status_calculator.dart';

/// Rolling seven-day cumulative load, moving average and direction for each of
/// the five World Status dimensions and for the total.
///
/// Rules (all covered by tests):
///  * The window is the 7 local dates ending on `asOf`, inclusive.
///  * A date with no entry, or an entry whose reading is
///    [DataStatus.unknown], is **unknown**. It is skipped, never read as 0,
///    and it does not enter the denominator of the moving average.
///  * A measured zero is a value and is counted.
///  * Direction compares the `asOf` reading with the mean of the seven dates
///    before it, using the same +/-5 threshold and the same "fewer than three
///    observed days is Not enough history" rule as
///    [WorldStatusCalculator.calculateTrend].
///  * No Flutter or I/O imports; the calculator is pure and deterministic.
class WorldTrendCalculator {
  const WorldTrendCalculator();

  /// Score movement (in points) beyond which the trend is Rising or Easing.
  static const directionThreshold = 5.0;

  /// Length of the cumulative window in days.
  static const windowDays = 7;

  /// Summarises [history] for the window ending on [asOf].
  ///
  /// [history] may be in any order and may contain gaps or days outside the
  /// window. If [asOf] is omitted the latest date in [history] is used.
  ///
  /// Throws [ArgumentError] when two entries share a date, or when both
  /// [history] and [asOf] are empty/omitted.
  WorldTrendReport calculate7DayTrend(
    List<DailyWorldStatus> history, {
    LocalDate? asOf,
  }) {
    final byDate = <LocalDate, DailyWorldStatus>{};
    for (final entry in history) {
      if (byDate.containsKey(entry.localDate)) {
        throw ArgumentError.value(
          entry.localDate.toString(),
          'history',
          'Duplicate entry for the same local date.',
        );
      }
      byDate[entry.localDate] = entry;
    }
    final end =
        asOf ??
        (byDate.isEmpty
            ? throw ArgumentError(
                'asOf is required when history is empty.',
              )
            : byDate.keys.reduce((a, b) => a.compareTo(b) >= 0 ? a : b));

    DimensionReading reading(
      LocalDate date,
      DimensionReading Function(DailyWorldStatus) pick,
    ) {
      final day = byDate[date];
      return day == null ? const DimensionReading.unknown() : pick(day);
    }

    DimensionTrend summarise(
      DimensionReading Function(DailyWorldStatus) pick,
    ) {
      final window = [
        for (var offset = windowDays - 1; offset >= 0; offset--)
          reading(end.addDays(-offset), pick),
      ];
      final previous = [
        for (var offset = 1; offset <= windowDays; offset++)
          reading(end.addDays(-offset), pick),
      ];
      return _summarise(window: window, previous: previous);
    }

    return WorldTrendReport(
      windowStart: end.addDays(-(windowDays - 1)),
      windowEnd: end,
      dimensions: {
        for (final dimension in WorldDimension.values)
          dimension: summarise((day) => day[dimension]),
      },
      total: summarise((day) => day.total),
    );
  }

  static DimensionTrend _summarise({
    required List<DimensionReading> window,
    required List<DimensionReading> previous,
  }) {
    final observed = window.map((r) => r.value).whereType<double>().toList();
    final sum = observed.fold<double>(0, (a, b) => a + b);
    final latest = window.last;
    final prior = previous.map((r) => r.value).whereType<double>().toList();
    final baseline = prior.length < DimensionTrend.minimumHistoryDays
        ? null
        : prior.fold<double>(0, (a, b) => a + b) / prior.length;

    return DimensionTrend(
      cumulativeLoad: observed.isEmpty ? null : sum,
      movingAverage: observed.isEmpty ? null : sum / observed.length,
      latest: latest,
      baseline: baseline,
      knownDays: window.where((r) => r.status == DataStatus.known).length,
      partialDays: window.where((r) => r.status == DataStatus.partial).length,
      unknownDays: window.where((r) => r.isUnknown).length,
      direction: _direction(latest.value, baseline),
    );
  }

  static WorldTrend _direction(double? latest, double? baseline) {
    if (latest == null || baseline == null) return WorldTrend.notEnoughHistory;
    final difference = latest - baseline;
    if (difference > directionThreshold) return WorldTrend.rising;
    if (difference < -directionThreshold) return WorldTrend.easing;
    return WorldTrend.stable;
  }
}
