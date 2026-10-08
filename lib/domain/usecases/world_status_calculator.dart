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
      _WorldStatusComponent(
        label: 'Daily Review energy',
        weight: .30,
        score: _energyPressure(input.mentalEnergy),
        evidence: input.mentalEnergy == null
            ? 'No energy rating was shared.'
            : 'Reported ${input.mentalEnergy!.name} energy.',
      ),
      _WorldStatusComponent(
        label: 'Tasks and deadlines',
        weight: .25,
        score: countPressure == null || deadlinePressure == null
            ? null
            : (countPressure + deadlinePressure) / 2,
        evidence: taskCount == null || dueSoon == null
            ? 'Task data is unavailable.'
            : '$taskCount unfinished tasks; $dueSoon min due within 48 hours.',
        sources: (tasks ?? const <WorldStatusTask>[])
            .where((task) => _isDueSoon(task, input.windowStart))
            .map((task) => task.title)
            .toList(growable: false),
      ),
      _WorldStatusComponent(
        label: 'Capacity pressure',
        weight: .25,
        score: capacityPressure,
        evidence: input.plannedMinutes == null || input.availableMinutes == null
            ? 'Planned or available minutes are missing.'
            : '${input.plannedMinutes} min planned; ${input.availableMinutes} min available.',
        sources: (tasks ?? const <WorldStatusTask>[])
            .where((task) => task.scheduledStart != null)
            .map((task) => task.title)
            .toList(growable: false),
      ),
      _WorldStatusComponent(
        label: 'Protected recovery',
        weight: .20,
        score: recoveryDeficit,
        evidence: input.protectedRecoveryMinutes == null
            ? 'Protected recovery data is unavailable.'
            : '${input.protectedRecoveryMinutes} of ${input.targetRecoveryMinutes} min protected.',
        sources: input.protectedRecoverySources,
      ),
    ], minimumKnownWeight: .5);
    final time = input.availableMinutes == null
        ? const DimensionResult.unknown('Add availability to calculate Time.')
        : _components([
            _WorldStatusComponent(
              label: 'Capacity gap',
              weight: .50,
              score: capacityPressure,
              evidence: input.plannedMinutes == null
                  ? 'Planned minutes are missing; ${input.availableMinutes} min available.'
                  : '${input.plannedMinutes} min planned; ${input.availableMinutes} min available.',
              sources: (tasks ?? const <WorldStatusTask>[])
                  .where((task) => task.scheduledStart != null)
                  .map((task) => task.title)
                  .toList(growable: false),
            ),
            _WorldStatusComponent(
              label: 'Deadlines within 48 hours',
              weight: .25,
              score: deadlinePressure,
              evidence: dueSoon == null
                  ? 'Task data is unavailable.'
                  : '$dueSoon min due within 48 hours.',
              sources: (tasks ?? const <WorldStatusTask>[])
                  .where((task) => _isDueSoon(task, input.windowStart))
                  .map((task) => task.title)
                  .toList(growable: false),
            ),
            _WorldStatusComponent(
              label: 'Unfinished task count',
              weight: .10,
              score: countPressure,
              evidence: taskCount == null
                  ? 'Task data is unavailable.'
                  : '$taskCount unfinished tasks (8-task reference scale).',
              sources: (tasks ?? const <WorldStatusTask>[])
                  .map((task) => task.title)
                  .toList(growable: false),
            ),
            _WorldStatusComponent(
              label: 'Protected recovery',
              weight: .15,
              score: recoveryDeficit,
              evidence: input.protectedRecoveryMinutes == null
                  ? 'Protected recovery data is unavailable.'
                  : '${input.protectedRecoveryMinutes} of ${input.targetRecoveryMinutes} min protected.',
              sources: input.protectedRecoverySources,
            ),
          ], minimumKnownWeight: .5);

    final physical =
        !input.movementTrackingEnabled || input.lastExerciseDate == null
        ? const DimensionResult.unknown(
            'Enable movement tracking and record an exercise to calculate Physical.',
          )
        : _components([
            _WorldStatusComponent(
              label: 'Days since recorded exercise',
              weight: .70,
              score: _cap(
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
              evidence:
                  'Target interval: every ${input.movementTargetDays} days.',
              sources: [
                'Latest confirmed exercise: ${_dateLabel(input.lastExerciseDate!)}',
              ],
            ),
            _WorldStatusComponent(
              label: 'Daily Review physical energy',
              weight: .30,
              score: _energyPressure(input.physicalEnergy),
              evidence: input.physicalEnergy == null
                  ? 'No physical-energy rating was shared.'
                  : 'Reported ${input.physicalEnergy!.name} energy.',
            ),
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
        errands = DimensionResult.known(
          0,
          contributions: const [
            WorldStatusContribution(
              label: 'Unfinished Errand work',
              weight: 1,
              score: 0,
              points: 0,
              evidence:
                  'All unfinished tasks are categorised; none are Errands.',
            ),
          ],
        );
      } else {
        errands = _components([
          _WorldStatusComponent(
            label: 'Remaining Errand minutes',
            weight: .60,
            score: input.availableMinutes == null
                ? null
                : _cap(
                    errandMinutes / math.max(input.availableMinutes!, 1) * 100,
                  ),
            evidence: input.availableMinutes == null
                ? 'Availability is missing.'
                : '$errandMinutes min of Errand work; ${input.availableMinutes} min available.',
            sources: errandTasks
                .map((task) => task.title)
                .toList(growable: false),
          ),
          _WorldStatusComponent(
            label: 'Errands due within 48 hours',
            weight: .25,
            score: _cap(errandDueSoon / errandMinutes * 100),
            evidence:
                '$errandDueSoon of $errandMinutes min due within 48 hours.',
            sources: errandTasks
                .where((task) => _isDueSoon(task, input.windowStart))
                .map((task) => task.title)
                .toList(growable: false),
          ),
          _WorldStatusComponent(
            label: 'Unfinished Errand count',
            weight: .15,
            score: _cap(errandTasks.length / 8 * 100),
            evidence:
                '${errandTasks.length} unfinished Errand tasks (8-task reference scale).',
            sources: errandTasks
                .map((task) => task.title)
                .toList(growable: false),
          ),
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
    final sources = events
        .map((event) => event.sourceLabel)
        .whereType<String>()
        .toList(growable: false);
    return DimensionResult.fromRaw(
      .7 * load + .3 * conflict,
      contributions: [
        WorldStatusContribution(
          label: 'User-reported event pressure',
          weight: .70,
          score: load,
          points: load * .70,
          evidence:
              '$totalMinutes min recorded; $weightedMinutes pressure-weighted minutes.',
          sources: sources,
        ),
        WorldStatusContribution(
          label: 'Schedule conflicts',
          weight: .30,
          score: conflict,
          points: conflict * .30,
          evidence:
              '$conflictMinutes of $totalMinutes event minutes overlap other commitments.',
          sources: sources,
        ),
      ],
    );
  }

  static DimensionResult _components(
    List<_WorldStatusComponent> components, {
    required double minimumKnownWeight,
  }) {
    var knownWeight = 0.0;
    var weighted = 0.0;
    var totalWeight = 0.0;
    for (final entry in components) {
      final weight = entry.weight;
      totalWeight += weight;
      if (entry.score != null) {
        knownWeight += weight;
        weighted += weight * entry.score!;
      }
    }
    if (knownWeight + 1e-9 < minimumKnownWeight) {
      return const DimensionResult.unknown('More recorded data is needed.');
    }
    final contributions = components
        .map(
          (component) => WorldStatusContribution(
            label: component.label,
            weight: component.weight,
            score: component.score,
            points: component.score == null
                ? null
                : component.score! * component.weight / knownWeight,
            evidence: component.evidence,
            sources: component.sources,
          ),
        )
        .toList(growable: false);
    return DimensionResult.fromRaw(
      weighted / knownWeight,
      isPartial: knownWeight + 1e-9 < totalWeight,
      contributions: contributions,
    );
  }

  static bool _isDueSoon(WorldStatusTask task, DateTime windowStart) =>
      !task.dueAt.isBefore(windowStart) &&
      !task.dueAt.isAfter(windowStart.add(const Duration(hours: 48)));

  static String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
    this.id,
    this.title = 'Untitled task',
    this.scheduledStart,
  }) : assert(remainingMinutes >= 0);
  final String? id;
  final String title;
  final int remainingMinutes;
  final DateTime dueAt;
  final LoadCategory? category;
  final DateTime? scheduledStart;
}

class WorldSocialEvent {
  const WorldSocialEvent({
    required this.durationMinutes,
    required this.pressure,
    this.conflictMinutes = 0,
    this.sourceLabel,
  }) : assert(durationMinutes > 0),
       assert(conflictMinutes >= 0 && conflictMinutes <= durationMinutes);
  final int durationMinutes;
  final SocialPressure pressure;
  final int conflictMinutes;
  final String? sourceLabel;
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
    this.protectedRecoverySources = const [],
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
  final List<String> protectedRecoverySources;
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
  DimensionResult.fromRaw(
    double value, {
    this.isPartial = false,
    this.reason,
    this.contributions = const [],
  }) : score = value.round(),
       rawScore = value;
  const DimensionResult.known(int value, {this.contributions = const []})
    : score = value,
      rawScore = value * 1.0,
      isPartial = false,
      reason = null;
  const DimensionResult.unknown(this.reason)
    : score = null,
      rawScore = null,
      isPartial = false,
      contributions = const [];
  final int? score;

  /// Kept unrounded so the total follows the versioned formula exactly.
  final double? rawScore;
  final bool isPartial;
  final String? reason;
  final List<WorldStatusContribution> contributions;
}

class WorldStatusContribution {
  const WorldStatusContribution({
    required this.label,
    required this.weight,
    required this.score,
    required this.points,
    required this.evidence,
    this.sources = const [],
  });

  final String label;
  final double weight;
  final double? score;
  final double? points;
  final String evidence;
  final List<String> sources;
}

class _WorldStatusComponent {
  const _WorldStatusComponent({
    required this.label,
    required this.weight,
    required this.score,
    required this.evidence,
    this.sources = const [],
  });

  final String label;
  final double weight;
  final double? score;
  final String evidence;
  final List<String> sources;
}

class WorldStatusResult {
  factory WorldStatusResult.fromSnapshot(Map<String, dynamic> row) {
    final dimensions = <WorldDimension, DimensionResult>{};
    for (final dimension in WorldDimension.values) {
      final value = row['${dimension.name}_score'] as num?;
      dimensions[dimension] = value == null
          ? const DimensionResult.unknown('No value was recorded for this day.')
          : DimensionResult.fromRaw(value.toDouble());
    }
    final coverage = (row['coverage'] as num).toDouble();
    return WorldStatusResult(
      dimensions: dimensions,
      totalScore: (row['total_score'] as num?)?.toInt(),
      coverage: coverage,
      // Older snapshots do not record component-level coverage.
      isPartial: row['is_partial'] as bool? ?? true,
      trend: switch (row['trend']) {
        'rising' => WorldTrend.rising,
        'easing' => WorldTrend.easing,
        'stable' => WorldTrend.stable,
        _ => WorldTrend.notEnoughHistory,
      },
    );
  }

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
