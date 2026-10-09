import 'package:balance/domain/models/local_date.dart';
import 'package:balance/domain/models/world_trend_models.dart';
import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:balance/domain/usecases/world_trend_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = WorldTrendCalculator();
  final today = LocalDate(2026, 10, 4);

  /// A status [daysAgo] days before [today] with only Time (and optionally the
  /// total) filled in; every other dimension stays Unknown.
  DailyWorldStatus day(
    int daysAgo,
    DimensionReading time, {
    DimensionReading total = const DimensionReading.unknown(),
  }) => DailyWorldStatus(
    localDate: today.addDays(-daysAgo),
    readings: {WorldDimension.time: time},
    total: total,
  );

  DimensionReading known(double v) => DimensionReading.known(v);
  const unknown = DimensionReading.unknown();

  group('DimensionReading: Unknown is not zero', () {
    test('unknown has a null value and is not equal to a measured zero', () {
      expect(unknown.value, isNull);
      expect(unknown.isUnknown, isTrue);
      expect(known(0).value, 0.0);
      expect(known(0).isUnknown, isFalse);
      expect(unknown, isNot(equals(known(0))));
    });

    test('rejects out-of-range and non-finite scores', () {
      expect(() => DimensionReading.known(-0.1), throwsArgumentError);
      expect(() => DimensionReading.known(100.1), throwsArgumentError);
      expect(() => DimensionReading.partial(double.nan), throwsArgumentError);
      expect(DimensionReading.known(100).value, 100.0);
    });

    test('JSON round trip keeps known, partial, unknown and zero apart', () {
      for (final reading in [
        known(0),
        known(42.5),
        DimensionReading.partial(10),
        unknown,
      ]) {
        expect(DimensionReading.fromJson(reading.toJson()), reading);
      }
    });

    test('JSON with an inconsistent status and value is rejected', () {
      expect(
        () => DimensionReading.fromJson({'value': 0, 'status': 'unknown'}),
        throwsFormatException,
      );
      expect(
        () => DimensionReading.fromJson({'value': null, 'status': 'known'}),
        throwsFormatException,
      );
      expect(
        () => DimensionReading.fromJson({'value': 1, 'status': 'bogus'}),
        throwsFormatException,
      );
    });

    test('copyWith keeps the invariant', () {
      expect(known(5).copyWith(value: 9), known(9));
      expect(known(5).copyWith(status: DataStatus.partial).isPartial, isTrue);
      expect(known(5).copyWith(status: DataStatus.unknown), unknown);
      expect(() => unknown.copyWith(status: DataStatus.known), throwsArgumentError);
    });

    test('fromResult maps calculator results without coercing Unknown', () {
      expect(
        DimensionReading.fromResult(const DimensionResult.unknown('x')),
        unknown,
      );
      expect(
        DimensionReading.fromResult(const DimensionResult.known(0)),
        known(0),
      );
      expect(
        DimensionReading.fromResult(
          DimensionResult.fromRaw(33.5, isPartial: true),
        ),
        DimensionReading.partial(33.5),
      );
    });
  });

  group('DailyWorldStatus', () {
    test('fills missing dimensions with Unknown and is unmodifiable', () {
      final status = day(0, known(30));
      expect(status[WorldDimension.time], known(30));
      expect(status[WorldDimension.mental], unknown);
      expect(status.readings.length, WorldDimension.values.length);
      expect(
        () => status.readings[WorldDimension.mental] = known(1),
        throwsUnsupportedError,
      );
    });

    test('JSON round trip and value equality', () {
      final status = day(2, known(30), total: DimensionReading.partial(40));
      final copy = DailyWorldStatus.fromJson(status.toJson());
      expect(copy, status);
      expect(copy.hashCode, status.hashCode);
      expect(status.copyWith(total: known(1)), isNot(equals(status)));
    });

    test('fromResult keeps null snapshot scores Unknown, not 0', () {
      final result = WorldStatusResult.fromSnapshot({
        'mental_score': 40,
        'time_score': 0,
        'physical_score': null,
        'social_score': null,
        'errands_score': null,
        'total_score': null,
        'coverage': 0.55,
        'is_partial': true,
        'trend': 'stable',
      });
      final status = DailyWorldStatus.fromResult(today, result);
      expect(status[WorldDimension.time], known(0));
      expect(status[WorldDimension.physical], unknown);
      expect(status.total, unknown);
    });
  });

  group('7-day cumulative load and moving average', () {
    test('seven known days: sum, average and coverage', () {
      final history = [
        for (var i = 0; i < 7; i++) day(6 - i, known(10.0 * (i + 1))),
      ]; // 10, 20, ..., 70 oldest to newest
      final trend = calculator.calculate7DayTrend(history)[WorldDimension.time];
      expect(trend.cumulativeLoad, closeTo(280, 1e-9));
      expect(trend.movingAverage, closeTo(40, 1e-9));
      expect(trend.knownDays, 7);
      expect(trend.unknownDays, 0);
      expect(trend.coverage, 1.0);
      expect(trend.latest, known(70));
    });

    test('missing dates are skipped and do not skew the denominator', () {
      final history = [day(0, known(90)), day(2, known(60)), day(5, known(30))];
      final trend = calculator.calculate7DayTrend(history)[WorldDimension.time];
      expect(trend.cumulativeLoad, closeTo(180, 1e-9));
      expect(trend.movingAverage, closeTo(60, 1e-9)); // 180 / 3, not 180 / 7
      expect(trend.knownDays, 3);
      expect(trend.unknownDays, 4);
      expect(trend.coverage, closeTo(3 / 7, 1e-9));
    });

    test('explicit Unknown entries behave like missing dates', () {
      final withUnknown = [
        day(0, known(90)),
        day(1, unknown),
        day(2, known(60)),
        day(3, unknown),
      ];
      final withoutThem = [day(0, known(90)), day(2, known(60))];
      final a = calculator.calculate7DayTrend(withUnknown)[WorldDimension.time];
      final b = calculator.calculate7DayTrend(withoutThem)[WorldDimension.time];
      expect(a.movingAverage, b.movingAverage);
      expect(a.cumulativeLoad, b.cumulativeLoad);
      expect(a.unknownDays, 5);
    });

    test('a measured zero is counted; it is not skipped', () {
      final history = [day(0, known(60)), day(1, known(0)), day(2, known(0))];
      final trend = calculator.calculate7DayTrend(history)[WorldDimension.time];
      expect(trend.movingAverage, closeTo(20, 1e-9)); // 60 / 3, not 60 / 1
      expect(trend.knownDays, 3);
    });

    test('a window with no observed value has null load, never 0', () {
      final trend = calculator.calculate7DayTrend([
        day(0, unknown),
        day(3, unknown),
      ])[WorldDimension.time];
      expect(trend.cumulativeLoad, isNull);
      expect(trend.movingAverage, isNull);
      expect(trend.unknownDays, 7);
      expect(trend.direction, WorldTrend.notEnoughHistory);
      // A dimension nobody ever filled in is Unknown too.
      final mental = calculator.calculate7DayTrend([
        day(0, known(10)),
      ])[WorldDimension.mental];
      expect(mental.movingAverage, isNull);
    });

    test('partial days contribute their value and are counted separately', () {
      final trend = calculator.calculate7DayTrend([
        day(0, known(40)),
        day(1, DimensionReading.partial(20)),
      ])[WorldDimension.time];
      expect(trend.movingAverage, closeTo(30, 1e-9));
      expect(trend.knownDays, 1);
      expect(trend.partialDays, 1);
      expect(trend.knownDays + trend.partialDays + trend.unknownDays, 7);
    });

    test('dates outside the window are ignored; order does not matter', () {
      final history = [
        day(0, known(50)),
        day(6, known(10)),
        day(7, known(100)), // eighth day: outside the window
        day(20, known(100)),
      ];
      final shuffled = [history[3], history[1], history[0], history[2]];
      final a = calculator.calculate7DayTrend(history);
      final b = calculator.calculate7DayTrend(shuffled);
      expect(a[WorldDimension.time].cumulativeLoad, closeTo(60, 1e-9));
      expect(b[WorldDimension.time].cumulativeLoad, closeTo(60, 1e-9));
      expect(a.windowStart, today.addDays(-6));
      expect(a.windowEnd, today);
    });

    test('asOf defaults to the latest date but can be given explicitly', () {
      final history = [day(3, known(10)), day(1, known(20))];
      expect(calculator.calculate7DayTrend(history).windowEnd, today.addDays(-1));
      final explicit = calculator.calculate7DayTrend(history, asOf: today);
      expect(explicit.windowEnd, today);
      expect(explicit[WorldDimension.time].latest, unknown);
    });

    test('the total is summarised like a dimension', () {
      final trend = calculator.calculate7DayTrend([
        day(0, unknown, total: known(60)),
        day(1, unknown, total: known(40)),
      ]).total;
      expect(trend.movingAverage, closeTo(50, 1e-9));
    });

    test('empty history needs asOf; duplicate dates are rejected', () {
      expect(() => calculator.calculate7DayTrend([]), throwsArgumentError);
      final empty = calculator.calculate7DayTrend([], asOf: today);
      for (final dimension in WorldDimension.values) {
        expect(empty[dimension].movingAverage, isNull);
        expect(empty[dimension].unknownDays, 7);
      }
      expect(
        () => calculator.calculate7DayTrend([
          day(1, known(1)),
          day(1, known(2)),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('Direction (WS08 thresholds)', () {
    /// Previous seven days all at [prior], today at [now].
    WorldTrend directionFor(double? now, {double prior = 40, int priorDays = 7}) {
      final history = [
        day(0, now == null ? unknown : known(now)),
        for (var i = 1; i <= priorDays; i++) day(i, known(prior)),
      ];
      return calculator.calculate7DayTrend(history)[WorldDimension.time].direction;
    }

    test('beyond +5 is Rising, beyond -5 is Easing, otherwise Stable', () {
      expect(directionFor(50), WorldTrend.rising);
      expect(directionFor(45.01), WorldTrend.rising);
      expect(directionFor(45), WorldTrend.stable); // exactly +5 is not Rising
      expect(directionFor(40), WorldTrend.stable);
      expect(directionFor(35), WorldTrend.stable); // exactly -5 is not Easing
      expect(directionFor(34.99), WorldTrend.easing);
      expect(directionFor(0), WorldTrend.easing); // a real zero is a value
    });

    test('fewer than three observed prior days is Not enough history', () {
      expect(directionFor(90, priorDays: 2), WorldTrend.notEnoughHistory);
      expect(directionFor(90, priorDays: 3), WorldTrend.rising);
    });

    test('an Unknown latest day is Not enough history', () {
      expect(directionFor(null), WorldTrend.notEnoughHistory);
    });

    test('agrees with the single-day WorldStatusCalculator.calculateTrend', () {
      final cases = <({int today, List<int?> previous})>[
        (today: 53, previous: [40, 42, 38, null, null, null, null]),
        (today: 20, previous: [40, 42, 38, 41, null, null, null]),
        (today: 41, previous: [40, 42, 38, 41, 40, 39, 43]),
        (today: 60, previous: [40, 42, null, null, null, null, null]),
      ];
      for (final c in cases) {
        final history = [
          day(0, unknown, total: known(c.today.toDouble())),
          for (var i = 0; i < 7; i++)
            if (c.previous[i] != null)
              day(i + 1, unknown, total: known(c.previous[i]!.toDouble())),
        ];
        expect(
          calculator.calculate7DayTrend(history).total.direction,
          WorldStatusCalculator.calculateTrend(c.today, c.previous),
          reason: '$c',
        );
      }
    });
  });
}
