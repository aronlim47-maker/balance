import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 9, 27);
  final start = DateTime(2026, 9, 27, 18);
  const calculator = WorldStatusCalculator();

  WorldStatusInput fixture({
    int? available = 180,
    int? planned = 300,
    List<WorldStatusTask>? tasks,
    EnergyLevel? mental = EnergyLevel.moderate,
    bool movementTracking = true,
    DateTime? lastExercise,
    List<WorldSocialEvent>? social,
    bool noSocial = false,
    int? recovery = 0,
  }) => WorldStatusInput(
    localDate: date,
    windowStart: start,
    previousSevenTotals: const [null, null, null, null, null, null, null],
    plannedMinutes: planned,
    availableMinutes: available,
    unfinishedTasks:
        tasks ??
        [
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
        ],
    protectedRecoveryMinutes: recovery,
    mentalEnergy: mental,
    physicalEnergy: EnergyLevel.high,
    movementTrackingEnabled: movementTracking,
    lastExerciseDate: lastExercise ?? DateTime(2026, 9, 21),
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

  test('worked example is 63, 63, 59, 18, 49 and total 53 High', () {
    final result = calculator.calculate(fixture());
    expect(result.dimensions.values.map((d) => d.score), [63, 63, 59, 18, 49]);
    expect(result.totalScore, 53);
    expect(result.coverage, 1);
    expect(result.knownDimensions.length, 5);
    expect(result.formulaVersion, 'world_status_v1');
    expect(result.label, 'High');
    expect(result.isPartial, false);
    expect(
      result.dimensions[WorldDimension.mental]!.contributions,
      hasLength(4),
    );
    expect(
      result.dimensions[WorldDimension.mental]!.contributions.first.points,
      closeTo(15, 0.01),
    );
    expect(
      result.dimensions[WorldDimension.social]!.contributions,
      hasLength(2),
    );
  });

  test('missing energy is partial rather than zero', () {
    final result = calculator.calculate(fixture(mental: null));
    expect(result.dimensions[WorldDimension.mental]!.score, isNotNull);
    expect(result.dimensions[WorldDimension.mental]!.isPartial, true);
    expect(result.isPartial, true);
  });

  test('missing availability makes Time unknown', () {
    final result = calculator.calculate(fixture(available: null));
    expect(result.dimensions[WorldDimension.time]!.score, isNull);
    expect(result.dimensions[WorldDimension.errands]!.score, isNull);
    expect(result.totalScore, isNull);
    expect(result.label, 'Not enough data');
  });

  test('missing planned minutes are not presented as zero', () {
    final result = calculator.calculate(fixture(planned: null));
    final time = result.dimensions[WorldDimension.time]!;
    expect(time.score, isNull);
    expect(time.reason, 'More recorded data is needed.');
    expect(time.contributions, isEmpty);
  });

  test('exercise history and opt in are both required', () {
    final result = calculator.calculate(fixture(movementTracking: false));
    expect(result.dimensions[WorldDimension.physical]!.score, isNull);
  });

  test('an unclassified unfinished task makes Errands unknown', () {
    final result = calculator.calculate(
      fixture(
        tasks: [
          WorldStatusTask(remainingMinutes: 40, dueAt: start, category: null),
        ],
      ),
    );
    expect(result.dimensions[WorldDimension.errands]!.score, isNull);
  });

  test('fully classified tasks without errands give a real zero', () {
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

  test('neutral event is known zero; no event without response is unknown', () {
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

  test('less than 60% known weight has no total', () {
    final result = calculator.calculate(
      WorldStatusInput(
        localDate: date,
        windowStart: start,
        previousSevenTotals: const [null, null, null, null, null, null, null],
        unfinishedTasks: const [],
      ),
    );
    expect(result.totalScore, isNull);
    expect(result.label, 'Not enough data');
  });

  test(
    'trend requires three prior totals and uses strict 5-point thresholds',
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

  test(
    'explicit zero availability and disabled recovery target stay finite',
    () {
      final result = calculator.calculate(
        WorldStatusInput(
          localDate: date,
          windowStart: start,
          previousSevenTotals: const [null, null, null, null, null, null, null],
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
      expect(
        result.dimensions[WorldDimension.mental]!.rawScore!.isFinite,
        true,
      );
    },
  );
}
