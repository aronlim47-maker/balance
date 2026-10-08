// Stress Meter acceptance tests (Rev7 14.4.7). Every test name starts with its
// WS ID so `flutter test --plain-name WS05` runs one case. The full map,
// including SQL and widget evidence for WS09–WS14, is in
// docs/WS_AND_ACHIEVEMENT_TEST_MAP.md. Covers Matthew's part.
import 'package:balance/domain/models/recovery_slot.dart';
import 'package:balance/domain/usecases/daily_capacity.dart';
import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 9, 27);
  final start = DateTime(2026, 9, 27, 18);
  const calculator = WorldStatusCalculator();
  const noHistory = <int?>[null, null, null, null, null, null, null];

  List<WorldStatusTask> workedTasks() => [
    WorldStatusTask(
      remainingMinutes: 30,
      dueAt: start.add(const Duration(hours: 12)),
      category: LoadCategory.errand,
    ),
    WorldStatusTask(
      remainingMinutes: 30,
      dueAt: start.add(const Duration(hours: 24)),
      category: LoadCategory.errand,
    ),
    WorldStatusTask(
      remainingMinutes: 60,
      dueAt: start.add(const Duration(hours: 36)),
      category: LoadCategory.study,
    ),
    WorldStatusTask(
      remainingMinutes: 180,
      dueAt: start.add(const Duration(days: 5)),
      category: LoadCategory.study,
    ),
  ];

  WorldStatusInput fixture({
    int? available = 180,
    int? planned = 300,
    List<WorldStatusTask>? tasks,
    EnergyLevel? mental = EnergyLevel.moderate,
    EnergyLevel? physical = EnergyLevel.high,
    bool movementTracking = true,
    bool hasExerciseHistory = true,
    DateTime? lastExercise,
    List<WorldSocialEvent>? social,
    bool noSocial = false,
    int? recovery = 0,
    List<int?> previous = noHistory,
  }) => WorldStatusInput(
    localDate: date,
    windowStart: start,
    previousSevenTotals: previous,
    plannedMinutes: planned,
    availableMinutes: available,
    unfinishedTasks: tasks ?? workedTasks(),
    protectedRecoveryMinutes: recovery,
    mentalEnergy: mental,
    physicalEnergy: physical,
    movementTrackingEnabled: movementTracking,
    lastExerciseDate: hasExerciseHistory
        ? lastExercise ?? DateTime(2026, 9, 21)
        : null,
    socialEvents:
    social ??
        const [
          WorldSocialEvent(
            durationMinutes: 120,
            pressure: SocialPressure.moderate,
          ),
        ],
    noSocialCommitments: noSocial,
  );

  int? score(WorldStatusResult result, WorldDimension dimension) =>
      result.dimensions[dimension]!.score;

  // Built through a function so invalid values are checked at run time.
  WorldSocialEvent socialEvent(int minutes, int conflictMinutes) =>
      WorldSocialEvent(
        durationMinutes: minutes,
        pressure: SocialPressure.high,
        conflictMinutes: conflictMinutes,
      );

  // ---------------------------------------------------------------- WS01
  test('WS01 worked example is 63, 63, 59, 18, 49 and total 53 High', () {
    final result = calculator.calculate(fixture());
    expect(result.dimensions.values.map((d) => d.score), [63, 63, 59, 18, 49]);
    expect(result.totalScore, 53);
    expect(result.coverage, 1);
    expect(result.knownDimensions.length, 5);
    expect(result.formulaVersion, 'world_status_v1');
    expect(result.label, 'High');
    expect(result.isPartial, false);
  });

  test('WS01 weights total 100% and bars keep the fixed order', () {
    final total = WorldStatusCalculator.weights.values.fold<double>(
      0,
          (sum, weight) => sum + weight,
    );
    expect(total, closeTo(1, 1e-9));
    expect(WorldStatusCalculator.weights[WorldDimension.time], .30);
    final result = calculator.calculate(fixture());
    expect(result.dimensions.keys.toList(), [
      WorldDimension.mental,
      WorldDimension.time,
      WorldDimension.physical,
      WorldDimension.social,
      WorldDimension.errands,
    ]);
  });

  test('WS01 labels follow the 25/50/75 bands', () {
    WorldStatusResult withTotal(int? value) => WorldStatusResult(
      dimensions: const {},
      totalScore: value,
      coverage: 1,
      isPartial: false,
      trend: WorldTrend.notEnoughHistory,
    );
    expect(withTotal(24).label, 'Low');
    expect(withTotal(25).label, 'Building');
    expect(withTotal(49).label, 'Building');
    expect(withTotal(50).label, 'High');
    expect(withTotal(74).label, 'High');
    expect(withTotal(75).label, 'Over capacity');
    expect(withTotal(null).label, 'Not enough data');
  });

  // ---------------------------------------------------------------- WS02
  test('WS02 missing energy is partial rather than zero', () {
    final result = calculator.calculate(fixture(mental: null));
    expect(result.dimensions[WorldDimension.mental]!.score, isNotNull);
    expect(result.dimensions[WorldDimension.mental]!.isPartial, true);
    expect(result.isPartial, true);
  });

  test('WS02 skipped energy is excluded, not scored as zero or High', () {
    final skipped = calculator.calculate(fixture(mental: null));
    // (0.25*45 + 0.25*66.67 + 0.20*100) / 0.70 = 68.45
    expect(skipped.dimensions[WorldDimension.mental]!.rawScore, closeTo(68.45, .01));
    expect(score(skipped, WorldDimension.mental), 68);
    // Different from every recorded energy choice, so it was not substituted.
    for (final level in EnergyLevel.values) {
      final recorded = calculator.calculate(fixture(mental: level));
      expect(score(recorded, WorldDimension.mental), isNot(68));
    }
    expect(skipped.totalScore, 55);
    expect(skipped.label, 'High');
  });

  test('WS02 Mental is Unknown when under half of its weight is known', () {
    final result = calculator.calculate(fixture(mental: null, available: null));
    expect(score(result, WorldDimension.mental), isNull);
    expect(result.dimensions[WorldDimension.mental]!.reason, isNotNull);
  });

  // ---------------------------------------------------------------- WS03
  test('WS03 missing availability makes Time unknown', () {
    final result = calculator.calculate(fixture(available: null));
    expect(result.dimensions[WorldDimension.time]!.score, isNull);
    expect(result.dimensions[WorldDimension.errands]!.score, isNull);
    expect(result.totalScore, isNull);
    expect(result.label, 'Not enough data');
  });

  test('WS03 planned 300 vs available 180 gives a positive Time gap', () {
    final overloaded = calculator.calculate(fixture());
    final fits = calculator.calculate(fixture(planned: 150));
    // capacity 66.7 -> Time 63; with no gap capacity is 0 -> Time 40.
    expect(score(overloaded, WorldDimension.time), 63);
    expect(score(fits, WorldDimension.time), 40);
    expect(score(fits, WorldDimension.mental), 51);
  });

  test('WS03 explicit zero availability and disabled recovery target stay finite', () {
    final result = calculator.calculate(
      WorldStatusInput(
        localDate: date,
        windowStart: start,
        previousSevenTotals: noHistory,
        plannedMinutes: 60,
        availableMinutes: 0,
        unfinishedTasks: [
          WorldStatusTask(
            remainingMinutes: 60,
            dueAt: start,
            category: LoadCategory.errand,
          ),
        ],
        protectedRecoveryMinutes: 0,
        targetRecoveryMinutes: 0,
      ),
    );
    expect(result.dimensions[WorldDimension.time]!.score, isNotNull);
    expect(result.dimensions[WorldDimension.errands]!.score, isNotNull);
    expect(result.dimensions[WorldDimension.mental]!.rawScore!.isFinite, true);
  });

  // ---------------------------------------------------------------- WS04
  test('WS04 exercise history and opt in are both required', () {
    final disabled = calculator.calculate(fixture(movementTracking: false));
    expect(disabled.dimensions[WorldDimension.physical]!.score, isNull);
    final noHistoryYet = calculator.calculate(
      fixture(hasExerciseHistory: false),
    );
    expect(score(noHistoryYet, WorldDimension.physical), isNull);
  });

  test('WS04 gap counts local days beyond the target interval', () {
    // Six days since exercise, three-day target: gap 3 -> 75 -> Physical 59.
    expect(score(calculator.calculate(fixture()), WorldDimension.physical), 59);
    // Two days since exercise is inside the target: only energy remains.
    expect(
      score(
        calculator.calculate(fixture(lastExercise: DateTime(2026, 9, 25))),
        WorldDimension.physical,
      ),
      6,
    );
    // Without physical energy the exercise gap alone is a partial score.
    final noEnergy = calculator.calculate(fixture(physical: null));
    expect(score(noEnergy, WorldDimension.physical), 75);
    expect(noEnergy.dimensions[WorldDimension.physical]!.isPartial, true);
  });

  // ---------------------------------------------------------------- WS05
  test('WS05 neutral event is known zero; no event without response is unknown', () {
    final neutral = calculator.calculate(
      fixture(
        social: const [
          WorldSocialEvent(
            durationMinutes: 60,
            pressure: SocialPressure.neutral,
          ),
        ],
      ),
    );
    expect(neutral.dimensions[WorldDimension.social]!.score, 0);
    final missing = calculator.calculate(fixture(social: const []));
    expect(missing.dimensions[WorldDimension.social]!.score, isNull);
    final explicitZero = calculator.calculate(
      fixture(social: const [], noSocial: true),
    );
    expect(explicitZero.dimensions[WorldDimension.social]!.score, 0);
  });

  test('WS05 a High event and a sleep overlap raise Social by the formula', () {
    final moderate = calculator.calculate(fixture());
    final high = calculator.calculate(
      fixture(
        social: const [
          WorldSocialEvent(durationMinutes: 120, pressure: SocialPressure.high),
        ],
      ),
    );
    final highWithOverlap = calculator.calculate(
      fixture(
        social: const [
          WorldSocialEvent(
            durationMinutes: 120,
            pressure: SocialPressure.high,
            conflictMinutes: 60,
          ),
        ],
      ),
    );
    expect(score(moderate, WorldDimension.social), 18);
    // eventLoad 40 -> 0.7*40 = 28; overlap 50% -> 28 + 0.3*50 = 43.
    expect(score(high, WorldDimension.social), 28);
    expect(score(highWithOverlap, WorldDimension.social), 43);
  });

  // ---------------------------------------------------------------- WS06
  test('WS06 an unclassified unfinished task makes Errands unknown', () {
    final result = calculator.calculate(
      fixture(
        tasks: [
          WorldStatusTask(remainingMinutes: 40, dueAt: start, category: null),
        ],
      ),
    );
    expect(result.dimensions[WorldDimension.errands]!.score, isNull);
  });

  test('WS06 fully classified tasks without errands give a real zero', () {
    final result = calculator.calculate(
      fixture(
        tasks: [
          WorldStatusTask(
            remainingMinutes: 40,
            dueAt: start,
            category: LoadCategory.study,
          ),
        ],
      ),
    );
    expect(result.dimensions[WorldDimension.errands]!.score, 0);
  });

  test('WS06 only the chosen category decides Errands, never the title', () {
    // WorldStatusTask has no title field, so a title cannot change the result.
    final asStudy = calculator.calculate(
      fixture(
        tasks: [
          for (final task in workedTasks())
            WorldStatusTask(
              remainingMinutes: task.remainingMinutes,
              dueAt: task.dueAt,
              category: LoadCategory.study,
            ),
        ],
      ),
    );
    expect(score(asStudy, WorldDimension.errands), 0);
    expect(score(calculator.calculate(fixture()), WorldDimension.errands), 49);
  });

  // ---------------------------------------------------------------- WS07
  test('WS07 protecting recovery lowers the Mental and Time deficit', () {
    final none = calculator.calculate(fixture(recovery: 0));
    final half = calculator.calculate(fixture(recovery: 15));
    final full = calculator.calculate(fixture(recovery: 30));
    expect(score(none, WorldDimension.mental), 63);
    expect(score(half, WorldDimension.mental), 53);
    expect(score(full, WorldDimension.mental), 43);
    expect(score(none, WorldDimension.time), 63);
    expect(score(full, WorldDimension.time), 48);
    expect(full.totalScore, 44);
  });

  test('WS07 marking a recovery activity done does not change capacity', () {
    final day = DateTime(2026, 9, 27);
    RecoverySlot slot({DateTime? completedAt, bool isProtected = true}) =>
        RecoverySlot(
          id: 'slot',
          startAt: DateTime(2026, 9, 27, 20),
          endAt: DateTime(2026, 9, 27, 20, 30),
          isProtected: isProtected,
          selectedActivity: 'Short walk',
          completedAt: completedAt,
        );
    DailyCapacity capacityWith(RecoverySlot recovery) => DailyCapacity.forDay(
      day: day,
      tasks: const [],
      availability: const [],
      recoverySlots: [recovery],
    );
    final reserved = capacityWith(slot());
    final done = capacityWith(slot(completedAt: DateTime(2026, 9, 27, 20, 30)));
    expect(reserved.recoveryMinutes, 30);
    expect(done.recoveryMinutes, reserved.recoveryMinutes);
    expect(capacityWith(slot(isProtected: false)).recoveryMinutes, 0);
  });

  // ---------------------------------------------------------------- WS08
  test(
    'WS08 trend requires three prior totals and uses strict 5-point thresholds',
        () {
      expect(
        WorldStatusCalculator.calculateTrend(60, const [
          50,
          50,
          null,
          null,
          null,
          null,
          null,
        ]),
        WorldTrend.notEnoughHistory,
      );
      expect(
        WorldStatusCalculator.calculateTrend(56, const [
          50,
          50,
          50,
          null,
          null,
          null,
          null,
        ]),
        WorldTrend.rising,
      );
      expect(
        WorldStatusCalculator.calculateTrend(55, const [
          50,
          50,
          50,
          null,
          null,
          null,
          null,
        ]),
        WorldTrend.stable,
      );
      expect(
        WorldStatusCalculator.calculateTrend(44, const [
          50,
          50,
          50,
          null,
          null,
          null,
          null,
        ]),
        WorldTrend.easing,
      );
    },
  );

  test('WS08 missing days are not zeros and not an improving trend', () {
    // If the four missing days were zeros the mean would be 21 and this would
    // read Rising; ignoring them gives a true Stable.
    expect(
      WorldStatusCalculator.calculateTrend(50, const [
        50,
        null,
        50,
        null,
        null,
        50,
        null,
      ]),
      WorldTrend.stable,
    );
    expect(
      WorldStatusCalculator.calculateTrend(null, const [
        50,
        50,
        50,
        50,
        50,
        50,
        50,
      ]),
      WorldTrend.notEnoughHistory,
    );
  });

  test('WS08 the calculator reports the trend for the selected day', () {
    final rising = calculator.calculate(
      fixture(previous: const [40, 40, 40, null, null, null, null]),
    );
    expect(rising.totalScore, 53);
    expect(rising.trend, WorldTrend.rising);
    expect(calculator.calculate(fixture()).trend, WorldTrend.notEnoughHistory);
  });

  // ------------------------------------- Invalid range / unit (WL07, WS08)
  test('WS08 trend input must be exactly seven local dates', () {
    expect(
          () => WorldStatusCalculator.calculateTrend(50, const [50, 50, 50]),
      throwsArgumentError,
    );
    expect(
          () => calculator.calculate(
        WorldStatusInput(
          localDate: date,
          windowStart: start,
          previousSevenTotals: const [50, 50, 50, 50, 50, 50],
          plannedMinutes: 300,
          availableMinutes: 180,
          unfinishedTasks: workedTasks(),
          protectedRecoveryMinutes: 0,
          mentalEnergy: EnergyLevel.moderate,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('WS01 invalid ranges are rejected before calculation', () {
    expect(
          () => WorldStatusInput(
        localDate: date,
        windowStart: start,
        previousSevenTotals: noHistory,
        plannedMinutes: -1,
      ),
      throwsAssertionError,
    );
    expect(
          () => WorldStatusInput(
        localDate: date,
        windowStart: start,
        previousSevenTotals: noHistory,
        availableMinutes: -30,
      ),
      throwsAssertionError,
    );
    expect(
          () => WorldStatusInput(
        localDate: date,
        windowStart: start,
        previousSevenTotals: noHistory,
        targetRecoveryMinutes: 241,
      ),
      throwsAssertionError,
    );
    expect(
          () => WorldStatusInput(
        localDate: date,
        windowStart: start,
        previousSevenTotals: noHistory,
        movementTargetDays: 15,
      ),
      throwsAssertionError,
    );
    expect(
          () => WorldStatusInput(
        localDate: date,
        windowStart: start,
        previousSevenTotals: noHistory,
        targetSocialMinutesWeek: 2001,
      ),
      throwsAssertionError,
    );
    expect(
          () => WorldStatusTask(
        remainingMinutes: -5,
        dueAt: start,
        category: LoadCategory.study,
      ),
      throwsAssertionError,
    );
    expect(() => socialEvent(0, 0), throwsAssertionError);
    expect(() => socialEvent(60, 90), throwsAssertionError);
  });

  test('WS01 every dimension and the total stay inside 0-100', () {
    final extreme = calculator.calculate(
      WorldStatusInput(
        localDate: date,
        windowStart: start,
        previousSevenTotals: noHistory,
        plannedMinutes: 100000,
        availableMinutes: 1,
        unfinishedTasks: [
          for (var i = 0; i < 20; i++)
            WorldStatusTask(
              remainingMinutes: 600,
              dueAt: start,
              category: LoadCategory.errand,
            ),
        ],
        protectedRecoveryMinutes: 0,
        mentalEnergy: EnergyLevel.low,
        physicalEnergy: EnergyLevel.low,
        movementTrackingEnabled: true,
        lastExerciseDate: DateTime(2026, 1, 1),
        socialEvents: [socialEvent(2000, 2000)],
      ),
    );
    for (final dimension in extreme.dimensions.values) {
      expect(dimension.score, inInclusiveRange(0, 100));
    }
    expect(extreme.totalScore, inInclusiveRange(0, 100));
    expect(score(extreme, WorldDimension.social), 100);
  });

  // ------------------------------------------- Midnight / week boundaries
  test('WS08 exercise gap uses calendar dates, not 24-hour periods', () {
    // 23:59 six calendar days earlier still counts as six days.
    expect(
      score(
        calculator.calculate(
          fixture(lastExercise: DateTime(2026, 9, 21, 23, 59)),
        ),
        WorldDimension.physical,
      ),
      59,
    );
    // 23:59 three calendar days earlier is inside the three-day target.
    expect(
      score(
        calculator.calculate(
          fixture(lastExercise: DateTime(2026, 9, 24, 23, 59)),
        ),
        WorldDimension.physical,
      ),
      6,
    );
  });

  test('WS08 the 48-hour due window includes its end and excludes overdue', () {
    WorldStatusResult dueAt(DateTime due) => calculator.calculate(
      WorldStatusInput(
        localDate: date,
        windowStart: start,
        previousSevenTotals: noHistory,
        plannedMinutes: 60,
        availableMinutes: 180,
        unfinishedTasks: [
          WorldStatusTask(
            remainingMinutes: 60,
            dueAt: due,
            category: LoadCategory.study,
          ),
        ],
      ),
    );
    final atEdge = dueAt(start.add(const Duration(hours: 48)));
    final justAfter = dueAt(start.add(const Duration(hours: 48, minutes: 1)));
    final overdue = dueAt(start.subtract(const Duration(minutes: 1)));
    expect(score(atEdge, WorldDimension.time), 31);
    expect(score(justAfter, WorldDimension.time), 1);
    expect(score(overdue, WorldDimension.time), 1);
  });

  // ---------------------------------------------------------- WS13 / WS14
  test('WS13 an unlinked Social task changes Time and Mental, not Social', () {
    final withSocialTask = calculator.calculate(
      fixture(
        planned: 360,
        tasks: [
          ...workedTasks(),
          WorldStatusTask(
            remainingMinutes: 60,
            dueAt: start.add(const Duration(hours: 20)),
            category: LoadCategory.social,
          ),
        ],
      ),
    );
    expect(score(withSocialTask, WorldDimension.time), 84);
    expect(score(withSocialTask, WorldDimension.mental), 74);
    expect(score(withSocialTask, WorldDimension.social), 18);
    final taskOnly = calculator.calculate(
      fixture(
        social: const [],
        tasks: [
          WorldStatusTask(
            remainingMinutes: 60,
            dueAt: start,
            category: LoadCategory.social,
          ),
        ],
      ),
    );
    expect(score(taskOnly, WorldDimension.social), isNull);
  });

  test('WS14 changing Study to Errand updates Errands', () {
    final tasks = workedTasks();
    final reclassified = calculator.calculate(
      fixture(
        tasks: [
          tasks[0],
          tasks[1],
          WorldStatusTask(
            remainingMinutes: tasks[2].remainingMinutes,
            dueAt: tasks[2].dueAt,
            category: LoadCategory.errand,
          ),
          tasks[3],
        ],
      ),
    );
    expect(score(calculator.calculate(fixture()), WorldDimension.errands), 49);
    expect(score(reclassified, WorldDimension.errands), 71);
    expect(reclassified.totalScore, 57);
  });

  test('WS14 coverage under 60% has no total', () {
    final result = calculator.calculate(
      WorldStatusInput(
        localDate: date,
        windowStart: start,
        previousSevenTotals: noHistory,
        unfinishedTasks: const [],
      ),
    );
    expect(result.totalScore, isNull);
    expect(result.label, 'Not enough data');
  });
}