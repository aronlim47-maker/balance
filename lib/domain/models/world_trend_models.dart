import '../usecases/world_status_calculator.dart';
import 'local_date.dart';

/// How much is known about a single measurement.
///
/// This is the explicit "Unknown vs zero" switch required by the World Status
/// spec (14.4.1). [unknown] means "nothing was collected"; it is never the same
/// thing as a measured `0.0`.
enum DataStatus {
  /// The value was fully computed from the approved inputs.
  known,

  /// The value was computed from only some of the approved inputs
  /// (for example Mental without a Daily Review energy). It is a real number,
  /// but the UI must label it as Partial.
  partial,

  /// No value could be computed. The numeric value is always `null`.
  unknown;

  static DataStatus parse(String? text) => switch (text) {
    'known' => DataStatus.known,
    'partial' => DataStatus.partial,
    'unknown' => DataStatus.unknown,
    _ => throw FormatException('Unknown DataStatus', text),
  };
}

/// One immutable reading of one World Status dimension (or of the total) on
/// one local date.
///
/// Invariant: [status] is [DataStatus.unknown] **if and only if** [value] is
/// `null`. A measured zero is `DimensionReading.known(0)` and has
/// `isUnknown == false`; nothing in this class ever coerces `null` to `0`.
///
/// Values are the unit-less 0–100 pressure scores produced by
/// `world_status_v1`.
class DimensionReading {
  const DimensionReading._(this.value, this.status);

  /// A fully computed score in the range 0–100 (0 is a real measured zero).
  factory DimensionReading.known(double value) =>
      DimensionReading._(_checked(value), DataStatus.known);

  /// A score computed from incomplete inputs, range 0–100.
  factory DimensionReading.partial(double value) =>
      DimensionReading._(_checked(value), DataStatus.partial);

  /// No data. [value] is `null`, never `0`.
  const DimensionReading.unknown() : value = null, status = DataStatus.unknown;

  /// Converts a calculator [DimensionResult] without losing the
  /// Unknown/Partial distinction. The unrounded `rawScore` is used so trend
  /// maths follows the versioned formula exactly.
  factory DimensionReading.fromResult(DimensionResult result) {
    final raw = result.rawScore;
    if (raw == null) return const DimensionReading.unknown();
    return result.isPartial
        ? DimensionReading.partial(raw)
        : DimensionReading.known(raw);
  }

  factory DimensionReading.fromJson(Map<String, dynamic> json) {
    final status = DataStatus.parse(json['status'] as String?);
    final raw = json['value'] as num?;
    switch (status) {
      case DataStatus.unknown:
        if (raw != null) {
          throw const FormatException('An unknown reading cannot have a value');
        }
        return const DimensionReading.unknown();
      case DataStatus.known:
      case DataStatus.partial:
        if (raw == null) {
          throw FormatException('A ${status.name} reading needs a value');
        }
        return status == DataStatus.known
            ? DimensionReading.known(raw.toDouble())
            : DimensionReading.partial(raw.toDouble());
    }
  }

  /// The score, or `null` when the reading is unknown.
  final double? value;
  final DataStatus status;

  bool get isUnknown => value == null;
  bool get isPartial => status == DataStatus.partial;

  /// True when [value] can be used in arithmetic (known or partial).
  bool get hasValue => value != null;

  DimensionReading copyWith({double? value, DataStatus? status}) {
    final nextStatus = status ?? this.status;
    if (nextStatus == DataStatus.unknown) {
      return const DimensionReading.unknown();
    }
    final nextValue = value ?? this.value;
    if (nextValue == null) {
      throw ArgumentError('A ${nextStatus.name} reading needs a value');
    }
    return nextStatus == DataStatus.known
        ? DimensionReading.known(nextValue)
        : DimensionReading.partial(nextValue);
  }

  Map<String, dynamic> toJson() => {'value': value, 'status': status.name};

  @override
  bool operator ==(Object other) =>
      other is DimensionReading &&
      other.value == value &&
      other.status == status;

  @override
  int get hashCode => Object.hash(value, status);

  @override
  String toString() => 'DimensionReading(${status.name}, $value)';

  static double _checked(double value) {
    if (!value.isFinite || value < 0 || value > 100) {
      throw ArgumentError.value(value, 'value', 'Must be finite and 0-100.');
    }
    return value;
  }
}

/// All five dimension readings (plus the weighted total) for one local date.
///
/// Missing dimensions are filled with [DimensionReading.unknown], so every
/// instance always exposes all five [WorldDimension] keys.
class DailyWorldStatus {
  DailyWorldStatus({
    required this.localDate,
    Map<WorldDimension, DimensionReading> readings = const {},
    this.total = const DimensionReading.unknown(),
  }) : readings = Map.unmodifiable({
         for (final dimension in WorldDimension.values)
           dimension: readings[dimension] ?? const DimensionReading.unknown(),
       });

  /// Builds a daily status from a calculator result for [localDate].
  factory DailyWorldStatus.fromResult(
    LocalDate localDate,
    WorldStatusResult result,
  ) {
    final score = result.totalScore;
    return DailyWorldStatus(
      localDate: localDate,
      readings: {
        for (final entry in result.dimensions.entries)
          entry.key: DimensionReading.fromResult(entry.value),
      },
      total: score == null
          ? const DimensionReading.unknown()
          : result.isPartial
          ? DimensionReading.partial(score.toDouble())
          : DimensionReading.known(score.toDouble()),
    );
  }

  factory DailyWorldStatus.fromJson(Map<String, dynamic> json) {
    final rawReadings = (json['readings'] as Map?)?.cast<String, dynamic>();
    return DailyWorldStatus(
      localDate: LocalDate.parse(json['localDate'] as String),
      readings: {
        for (final dimension in WorldDimension.values)
          if (rawReadings?[dimension.name] != null)
            dimension: DimensionReading.fromJson(
              (rawReadings![dimension.name] as Map).cast<String, dynamic>(),
            ),
      },
      total: json['total'] == null
          ? const DimensionReading.unknown()
          : DimensionReading.fromJson(
              (json['total'] as Map).cast<String, dynamic>(),
            ),
    );
  }

  final LocalDate localDate;

  /// Always contains all five dimensions; unmodifiable.
  final Map<WorldDimension, DimensionReading> readings;
  final DimensionReading total;

  DimensionReading operator [](WorldDimension dimension) =>
      readings[dimension]!;

  DailyWorldStatus copyWith({
    LocalDate? localDate,
    Map<WorldDimension, DimensionReading>? readings,
    DimensionReading? total,
  }) => DailyWorldStatus(
    localDate: localDate ?? this.localDate,
    readings: readings ?? this.readings,
    total: total ?? this.total,
  );

  Map<String, dynamic> toJson() => {
    'localDate': localDate.toString(),
    'readings': {
      for (final entry in readings.entries) entry.key.name: entry.value.toJson(),
    },
    'total': total.toJson(),
  };

  @override
  bool operator ==(Object other) {
    if (other is! DailyWorldStatus ||
        other.localDate != localDate ||
        other.total != total) {
      return false;
    }
    for (final dimension in WorldDimension.values) {
      if (other.readings[dimension] != readings[dimension]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    localDate,
    total,
    Object.hashAll(WorldDimension.values.map((d) => readings[d])),
  );
}

/// Seven-day summary of one dimension (or of the total).
class DimensionTrend {
  const DimensionTrend({
    required this.cumulativeLoad,
    required this.movingAverage,
    required this.latest,
    required this.baseline,
    required this.knownDays,
    required this.partialDays,
    required this.unknownDays,
    required this.direction,
  });

  /// Sum of the observed scores in the 7-day window ending on the as-of date,
  /// or `null` when no day had a value. It is **not** extrapolated: a window
  /// with three observed days sums three days. Compare windows with
  /// [movingAverage] or [coverage], not with this sum alone.
  final double? cumulativeLoad;

  /// [cumulativeLoad] divided by the number of days that had a value.
  /// Unknown days are excluded from the denominator. `null` when there is no
  /// observed day; never `0` as a stand-in.
  final double? movingAverage;

  /// The reading on the as-of date itself (may be unknown).
  final DimensionReading latest;

  /// Mean of the observed scores on the seven dates *before* the as-of date,
  /// the same baseline the single-day `WorldStatusCalculator.calculateTrend`
  /// uses. `null` when there are fewer than [minimumHistoryDays] of them.
  final double? baseline;

  /// Days in the 7-day window with a known / partial / unknown reading.
  /// Days missing from the history count as unknown.
  /// `knownDays + partialDays + unknownDays == 7`.
  final int knownDays;
  final int partialDays;
  final int unknownDays;

  final WorldTrend direction;

  /// Fewer observed prior days than this gives "Not enough history".
  static const minimumHistoryDays = 3;

  /// Days in the window that had a numeric value.
  int get observedDays => knownDays + partialDays;

  /// Share of the 7-day window that had a value, 0.0–1.0.
  double get coverage => observedDays / 7;
}

/// Result of [WorldTrendCalculator.calculate7DayTrend].
class WorldTrendReport {
  WorldTrendReport({
    required this.windowStart,
    required this.windowEnd,
    required Map<WorldDimension, DimensionTrend> dimensions,
    required this.total,
  }) : dimensions = Map.unmodifiable(dimensions);

  /// First and last local date of the 7-day window (inclusive).
  final LocalDate windowStart;
  final LocalDate windowEnd;
  final Map<WorldDimension, DimensionTrend> dimensions;
  final DimensionTrend total;

  DimensionTrend operator [](WorldDimension dimension) =>
      dimensions[dimension]!;
}
