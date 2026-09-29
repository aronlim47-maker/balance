import 'dart:math' as math;

import '../enums/load_category.dart';
import '../enums/energy_level.dart';
export '../enums/load_category.dart';
export '../enums/energy_level.dart';

/// Versioned planning indicator. It is not a health assessment.
class WorldStatusCalculator {
  static const formulaVersion = 'world_status_v1';
  static const weights = <WorldDimension, double>{
    WorldDimension.mental: .25,
    WorldDimension.time: .30,
    WorldDimension.physical: .15,
    WorldDimension.social: .15,
    WorldDimension.errands: .15,
  };

  const WorldStatusCalculator();

  WorldStatusResult calculate(WorldStatusInput input) {
    final tasks = input.unfinishedTasks;
    final taskCount = tasks?.length;
    final dueSoon = tasks
        ?.where(
          (task) =>
              !task.dueAt.isBefore(input.windowStart) &&
              !task.dueAt.isAfter(
                input.windowStart.add(const Duration(hours: 48)),
              ),
        )
        .fold<int>(0, (sum, task) => sum + task.remainingMinutes);
    final countPressure = taskCount == null ? null : _cap(taskCount / 8 * 100);
    final deadlinePressure = dueSoon == null || input.plannedMinutes == null
        ? null
        : _cap(dueSoon / math.max(input.plannedMinutes!, 1) * 100);
    final capacityPressure =
        input.availableMinutes == null || input.plannedMinutes == null
        ? null
        : input.availableMinutes == 0 && input.plannedMinutes! > 0
        ? 100.0
        : _cap(
            math.max(0, input.plannedMinutes! - input.availableMinutes!) /
                math.max(input.availableMinutes!, 1) *
                100,
          );
    final recoveryDeficit = input.protectedRecoveryMinutes == null
        ? null
        : input.targetRecoveryMinutes == 0
        ? 0.0
        : _cap(
            (input.targetRecoveryMinutes - input.protectedRecoveryMinutes!) /
                input.targetRecoveryMinutes *
                100,
          );

    final mental = _components([
      MapEntry(.30, _energyPressure(input.mentalEnergy)),
      MapEntry(
        .25,
        countPressure == null || deadlinePressure == null
            ? null
            : (countPressure + deadlinePressure) / 2,
      ),
      MapEntry(.25, capacityPressure),
      MapEntry(.20, recoveryDeficit),
    ], minimumKnownWeight: .5);
    final time = input.availableMinutes == null
        ? const DimensionResult.unknown('Add availability to calculate Time.')
        : _components([
            MapEntry(.50, capacityPressure),
            MapEntry(.25, deadlinePressure),
            MapEntry(.10, countPressure),
            MapEntry(.15, recoveryDeficit),
          ], minimumKnownWeight: .5);

    final physical =
        !input.movementTrackingEnabled || input.lastExerciseDate == null
        ? const DimensionResult.unknown(
            'Enable movement tracking and record an exercise to calculate Physical.',
          )
        : _components([
            MapEntry(
              .70,
              _cap(
                math.max(
                      0,
                      _localDay(input.localDate)
                              .difference(_localDay(input.lastExerciseDate!))
                              .inDays -
                          input.movementTargetDays,
                    ) /
                    4 *
                    100,
              ),
            ),
            MapEntry(.30, _energyPressure(input.physicalEnergy)),
          ], minimumKnownWeight: .7);

    final social =
        input.socialEvents == null ||
            (input.socialEvents!.isEmpty && !input.noSocialCommitments)
        ? const DimensionResult.unknown(
            'Add a social event or confirm no social commitments for this week.',
          )
        : _social(input);

    DimensionResult errands;
    if (tasks == null) {
      errands = const DimensionResult.unknown(
        'Load tasks to calculate Errands.',
      );
    } else if (tasks.any((task) => task.category == null)) {
      errands = const DimensionResult.unknown(
        'Review the categories of unfinished tasks.',
      );
    } else {
      final errandTasks = tasks.where(
        (task) => task.category == LoadCategory.errand,
      );
      final errandMinutes = errandTasks.fold<int>(
        0,
        (sum, task) => sum + task.remainingMinutes,
      );
      final errandDueSoon = errandTasks
          .where(
            (task) =>
                !task.dueAt.isBefore(input.windowStart) &&
                !task.dueAt.isAfter(
                  input.windowStart.add(const Duration(hours: 48)),
                ),
          )
          .fold<int>(0, (sum, task) => sum + task.remainingMinutes);
      if (errandMinutes == 0) {
        errands = const DimensionResult.known(0);
      } else {
        errands = _components([
          MapEntry(
            .60,
            input.availableMinutes == null
                ? null
                : _cap(
                    errandMinutes / math.max(input.availableMinutes!, 1) * 100,
                  ),
          ),
          MapEntry(.25, _cap(errandDueSoon / errandMinutes * 100)),
          MapEntry(.15, _cap(errandTasks.length / 8 * 100)),
        ], minimumKnownWeight: .6);
      }
    }

    final dimensions = <WorldDimension, DimensionResult>{
      WorldDimension.mental: mental,
      WorldDimension.time: time,
      WorldDimension.physical: physical,
      WorldDimension.social: social,
      WorldDimension.errands: errands,
    };
    var weighted = 0.0;
    var coverage = 0.0;
    for (final entry in dimensions.entries) {
      if (entry.value.rawScore == null) continue;
      final weight = weights[entry.key]!;
      weighted += entry.value.rawScore! * weight;
      coverage += weight;
    }
    final total = coverage + 1e-9 < .60 ? null : (weighted / coverage).round();
    return WorldStatusResult(
      dimensions: dimensions,
      totalScore: total,
      coverage: double.parse(coverage.toStringAsFixed(3)),
      isPartial:
          total != null &&
          (coverage < 1 || dimensions.values.any((d) => d.isPartial)),
      trend: calculateTrend(total, input.previousSevenTotals),
    );
  }

  static WorldTrend calculateTrend(int? today, List<int?> previousSevenTotals) {
    if (today == null) return WorldTrend.notEnoughHistory;
    if (previousSevenTotals.length != 7) {
      throw ArgumentError.value(
        previousSevenTotals.length,
        'previousSevenTotals',
        'Exactly seven local dates are required.',
      );
    }
    final known = previousSevenTotals.whereType<int>().toList();
    if (known.length < 3) return WorldTrend.notEnoughHistory;
    final difference = today - known.reduce((a, b) => a + b) / known.length;
    if (difference > 5) return WorldTrend.rising;
    if (difference < -5) return WorldTrend.easing;
    return WorldTrend.stable;
  }

  static DimensionResult _social(WorldStatusInput input) {
    final events = input.socialEvents!;
    final totalMinutes = events.fold<int>(
      0,
      (sum, event) => sum + event.durationMinutes,
    );
    final weightedMinutes = events.fold<int>(
      0,
      (sum, event) => sum + event.durationMinutes * event.pressure.value,
    );
    final conflictMinutes = events.fold<int>(
      0,
      (sum, event) => sum + event.conflictMinutes,
    );
    final load = _cap(
      weightedMinutes / math.max(input.targetSocialMinutesWeek * 80, 1) * 100,
    );
    final conflict = _cap(conflictMinutes / math.max(totalMinutes, 1) * 100);
    return DimensionResult.fromRaw(.7 * load + .3 * conflict);
  }

  static DimensionResult _components(
    List<MapEntry<double, double?>> components, {
    required double minimumKnownWeight,
  }) {
    var knownWeight = 0.0;
    var weighted = 0.0;
    var totalWeight = 0.0;
    for (final entry in components) {
      final weight = entry.key;
      totalWeight += weight;
      if (entry.value != null) {
        knownWeight += weight;
        weighted += weight * entry.value!;
      }
    }
    if (knownWeight + 1e-9 < minimumKnownWeight) {
      return const DimensionResult.unknown('More recorded data is needed.');
    }
    return DimensionResult.fromRaw(
      weighted / knownWeight,
      isPartial: knownWeight + 1e-9 < totalWeight,
    );
  }

  static double? _energyPressure(EnergyLevel? value) => switch (value) {
    EnergyLevel.low => 80,
    EnergyLevel.moderate => 50,
    EnergyLevel.high => 20,
    null => null,
  };
  static double _cap(num value) => value.clamp(0, 100).toDouble();
  static DateTime _localDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}

enum WorldDimension { mental, time, physical, social, errands }

enum SocialPressure {
  neutral(0),
  low(20),
  moderate(50),
  high(80);

  const SocialPressure(this.value);
  final int value;
}

enum WorldTrend { rising, stable, easing, notEnoughHistory }

class WorldStatusTask {
  const WorldStatusTask({
    required this.remainingMinutes,
    required this.dueAt,
    required this.category,
  }) : assert(remainingMinutes >= 0);
  final int remainingMinutes;
  final DateTime dueAt;
  final LoadCategory? category;
}

class WorldSocialEvent {
  const WorldSocialEvent({
    required this.durationMinutes,
    required this.pressure,
    this.conflictMinutes = 0,
  }) : assert(durationMinutes > 0),
       assert(conflictMinutes >= 0 && conflictMinutes <= durationMinutes);
  final int durationMinutes;
  final SocialPressure pressure;
  final int conflictMinutes;
}

class WorldStatusInput {
  const WorldStatusInput({
    required this.localDate,
    required this.windowStart,
    required this.previousSevenTotals,
    this.plannedMinutes,
    this.availableMinutes,
    this.unfinishedTasks,
    this.protectedRecoveryMinutes,
    this.targetRecoveryMinutes = 30,
    this.mentalEnergy,
    this.physicalEnergy,
    this.movementTrackingEnabled = false,
    this.lastExerciseDate,
    this.movementTargetDays = 3,
    this.socialEvents,
    this.noSocialCommitments = false,
    this.targetSocialMinutesWeek = 300,
  }) : assert(plannedMinutes == null || plannedMinutes >= 0),
       assert(availableMinutes == null || availableMinutes >= 0),
       assert(
         protectedRecoveryMinutes == null || protectedRecoveryMinutes >= 0,
       ),
       assert(targetRecoveryMinutes >= 0 && targetRecoveryMinutes <= 240),
       assert(movementTargetDays >= 1 && movementTargetDays <= 14),
       assert(targetSocialMinutesWeek >= 0 && targetSocialMinutesWeek <= 2000);
  final DateTime localDate;
  final DateTime windowStart;
  final List<int?> previousSevenTotals;
  final int? plannedMinutes;
  final int? availableMinutes;
  final List<WorldStatusTask>? unfinishedTasks;
  final int? protectedRecoveryMinutes;
  final int targetRecoveryMinutes;
  final EnergyLevel? mentalEnergy;
  final EnergyLevel? physicalEnergy;
  final bool movementTrackingEnabled;
  final DateTime? lastExerciseDate;
  final int movementTargetDays;
  final List<WorldSocialEvent>? socialEvents;
  final bool noSocialCommitments;
  final int targetSocialMinutesWeek;
}

class DimensionResult {
  DimensionResult.fromRaw(double value, {this.isPartial = false, this.reason})
    : score = value.round(),
      rawScore = value;
  const DimensionResult.known(int value)
    : score = value,
      rawScore = value * 1.0,
      isPartial = false,
      reason = null;
  const DimensionResult.unknown(this.reason)
    : score = null,
      rawScore = null,
      isPartial = false;
  final int? score;

  /// Kept unrounded so the total follows the versioned formula exactly.
  final double? rawScore;
  final bool isPartial;
  final String? reason;
}

class WorldStatusResult {
  const WorldStatusResult({
    required this.dimensions,
    required this.totalScore,
    required this.coverage,
    required this.isPartial,
    required this.trend,
  });
  final Map<WorldDimension, DimensionResult> dimensions;
  final int? totalScore;
  final double coverage;
  final bool isPartial;
  final WorldTrend trend;
  String get formulaVersion => WorldStatusCalculator.formulaVersion;
  Set<WorldDimension> get knownDimensions => dimensions.entries
      .where((entry) => entry.value.score != null)
      .map((entry) => entry.key)
      .toSet();
  String get label {
    final score = totalScore;
    if (score == null) return 'Not enough data';
    if (score < 25) return 'Low';
    if (score < 50) return 'Building';
    if (score < 75) return 'High';
    return 'Over capacity';
  }
}
