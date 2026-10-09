import 'package:balance/domain/enums/task_flexibility.dart';
import 'package:balance/domain/enums/validation_status.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/local_date.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/usecases/achievement_evaluator.dart';
import 'package:balance/domain/usecases/calculate_capacity.dart';
import 'package:balance/domain/usecases/daily_capacity.dart';
import 'package:balance/domain/usecases/generate_trade_offs.dart';
import 'package:balance/domain/usecases/validate_plan.dart';
import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Full-journey regression at domain level (no widgets, no network):
/// Create Tasks -> Detect Overload -> Compare Plans -> Confirm -> Protect
/// Recovery -> Undo, using the acceptance scenario of Build Phase Plan 9 and
/// 14.8 (300 minutes of work proposed for a 180-minute evening).
///
/// Dates: Monday 5 Oct 2026 is "tonight"; Thursday 8 Oct and Saturday 10 Oct
/// are the destination days. Screens, Supabase and real devices are covered by
/// widget tests, the SQL scripts and docs/BUILDING_EVIDENCE_PACK.md.
void main() {
  final tonight = DateTime(2026, 10, 5);
  final now = DateTime(2026, 10, 5, 16);
  final thursday = DateTime(2026, 10, 8);
  final saturday = DateTime(2026, 10, 10);
  final readingDue = DateTime(2026, 10, 9, 17);

  // Essential assignment: protected, fixed, 120 min, due tomorrow morning.
  final assignment = TaskItem(
    id: 'assignment',
    title: 'Essential assignment',
    estimatedMinutes: 120,
    remainingMinutes: 120,
    dueAt: DateTime(2026, 10, 6, 9),
    flexibility: TaskFlexibility.fixed,
    isProtected: true,
    loadCategory: LoadCategory.study,
    scheduledStart: DateTime(2026, 10, 5, 17),
    scheduledEnd: DateTime(2026, 10, 5, 19),
  );
  // Reading report: flexible, 120 min, due Friday.
  final reading = TaskItem(
    id: 'reading',
    title: 'Reading report',
    estimatedMinutes: 120,
    remainingMinutes: 120,
    dueAt: readingDue,
    loadCategory: LoadCategory.study,
    scheduledStart: DateTime(2026, 10, 5, 19),
    scheduledEnd: DateTime(2026, 10, 5, 21),
  );
  // Optional recording: flexible, 60 min. The source states no deadline, so the
  // fixture sets an explicit one after Saturday.
  final recording = TaskItem(
    id: 'recording',
    title: 'Optional recording',
    estimatedMinutes: 60,
    remainingMinutes: 60,
    dueAt: DateTime(2026, 10, 12, 18),
    isOptional: true,
    loadCategory: LoadCategory.other,
    scheduledStart: DateTime(2026, 10, 5, 21),
    scheduledEnd: DateTime(2026, 10, 5, 22),
  );
  final eveningAvailability = AvailabilityBlock(
    id: 'tonight',
    startAt: DateTime(2026, 10, 5, 17),
    endAt: DateTime(2026, 10, 5, 20),
    isAvailable: true,
  );

  DailyCapacity capacity(Iterable<TaskItem> tasks) => DailyCapacity.forDay(
    day: tonight,
    tasks: tasks,
    availability: [eveningAvailability],
  );

  WorldStatusResult status({
    required int planned,
    required int recoveryMinutes,
    required List<TaskItem> tasks,
  }) => const WorldStatusCalculator().calculate(
    WorldStatusInput(
      localDate: tonight,
      windowStart: DateTime(2026, 10, 5, 17),
      previousSevenTotals: const [null, null, null, null, null, null, null],
      plannedMinutes: planned,
      availableMinutes: 180,
      protectedRecoveryMinutes: recoveryMinutes,
      unfinishedTasks: [
        for (final task in tasks)
          WorldStatusTask(
            id: task.id,
            title: task.title,
            remainingMinutes: task.effectiveRemainingMinutes,
            dueAt: task.dueAt,
            category: task.loadCategory,
            scheduledStart: task.scheduledStart,
          ),
      ],
    ),
  );

  group('Step 1-2: create tasks and detect overload', () {
    test('300 planned in a 180-minute evening is a 120-minute overload', () {
      final snapshot = capacity([assignment, reading, recording]);
      expect(snapshot.plannedMinutes, 300);
      expect(snapshot.availableMinutes, 180);
      expect(snapshot.overloadMinutes, 120);
      expect(
        calculateOverload(
          plannedMinutes: snapshot.plannedMinutes,
          availableMinutes: snapshot.availableMinutes,
        ),
        120,
      );
    });

    test('World Status shows the overload and keeps missing data Unknown', () {
      final result = status(
        planned: 300,
        recoveryMinutes: 0,
        tasks: [assignment, reading, recording],
      );
      final time = result.dimensions[WorldDimension.time]!;
      expect(time.score, isNotNull);
      expect(time.score!, greaterThan(50));
      // Nothing was recorded for these two, so they are Unknown, not zero.
      expect(result.dimensions[WorldDimension.physical]!.score, isNull);
      expect(result.dimensions[WorldDimension.social]!.score, isNull);
      // All unfinished tasks are classified and none is an Errand: a real zero.
      expect(result.dimensions[WorldDimension.errands]!.score, 0);
      expect(result.totalScore, isNotNull);
      expect(result.isPartial, isTrue);
    });
  });

  group('Step 3: compare plans', () {
    test('a destination with room produces a plan that spares protected work', () {
      final options = generateTradeOffs(
        day: tonight,
        tasks: [assignment, reading, recording],
        availability: [
          eveningAvailability,
          AvailabilityBlock(
            id: 'thursday',
            startAt: DateTime(2026, 10, 8, 18),
            endAt: DateTime(2026, 10, 8, 20),
            isAvailable: true,
          ),
        ],
        now: now,
      );
      expect(options, isNotEmpty);
      for (final option in options) {
        for (final move in option.allMoves) {
          expect(move.taskId, isNot('assignment'));
          expect(move.proposedEnd.isAfter(readingDue), isFalse);
          expect(move.proposedStart.isAfter(now), isTrue);
        }
        expect(option.movedMinutes, greaterThanOrEqualTo(120));
      }
      expect(options.first.allMoves.first.proposedStart.day, thursday.day);
    });

    test('a protected-only evening has no plan to propose', () {
      final options = generateTradeOffs(
        day: tonight,
        tasks: [
          assignment,
          TaskItem(
            id: 'second-protected',
            title: 'Protected shift',
            estimatedMinutes: 120,
            remainingMinutes: 120,
            dueAt: DateTime(2026, 10, 6, 9),
            flexibility: TaskFlexibility.fixed,
            isProtected: true,
            scheduledStart: DateTime(2026, 10, 5, 19),
            scheduledEnd: DateTime(2026, 10, 5, 21),
          ),
        ],
        availability: [eveningAvailability],
        now: now,
      );
      expect(options, isEmpty);
    });

    test('status rules: unknown -> Needs Review, impossible -> No Feasible Plan', () {
      expect(
        validatePlan(
          hasRequiredInformation: false, // recording deadline unknown
          hasFeasibleCapacity: true,
          needsAgreement: false,
        ),
        ValidationStatus.needsReview,
      );
      expect(
        validatePlan(
          hasRequiredInformation: true,
          hasFeasibleCapacity: false, // Thursday/Saturday cannot fit the work
          needsAgreement: false,
        ),
        ValidationStatus.noFeasiblePlan,
      );
      expect(
        validatePlan(
          hasRequiredInformation: true,
          hasFeasibleCapacity: true,
          needsAgreement: true, // shared task without approval
        ),
        ValidationStatus.needsAgreement,
      );
    });
  });

  group('Step 4-5: confirm and protect recovery (14.8 arithmetic)', () {
    // The agreed plan: 30 of the 120 reading minutes stay tonight; 90 move to
    // Thursday; the 60-minute recording moves to Saturday.
    final readingTonight = TaskItem(
      id: 'reading',
      title: 'Reading report',
      estimatedMinutes: 120,
      remainingMinutes: 30,
      dueAt: readingDue,
      loadCategory: LoadCategory.study,
      scheduledStart: DateTime(2026, 10, 5, 19),
      scheduledEnd: DateTime(2026, 10, 5, 19, 30),
    );

    test('150 work minutes remain tonight and 30 are unallocated', () {
      final after = capacity([assignment, readingTonight]);
      expect(after.workMinutes, 150);
      expect(after.overloadMinutes, 0);
      expect(after.availableMinutes - after.workMinutes, 30);
    });

    test('the moved work fits its destination slots before the deadlines', () {
      final thursdaySlot = DateTime(2026, 10, 8, 18).add(
        const Duration(minutes: 90),
      );
      final saturdaySlot = DateTime(2026, 10, 10, 10).add(
        const Duration(minutes: 60),
      );
      expect(thursdaySlot.isAfter(readingDue), isFalse);
      expect(saturdaySlot.isAfter(recording.dueAt), isFalse);
      expect(thursday.weekday, DateTime.thursday);
      expect(saturday.weekday, DateTime.saturday);
    });

    test('Mental and Time pressure fall; protecting recovery lowers them again', () {
      final before = status(
        planned: 300,
        recoveryMinutes: 0,
        tasks: [assignment, reading, recording],
      );
      final moved = status(
        planned: 150,
        recoveryMinutes: 0,
        tasks: [assignment, readingTonight],
      );
      final protectedRecovery = status(
        planned: 150,
        recoveryMinutes: 30,
        tasks: [assignment, readingTonight],
      );
      int score(WorldStatusResult r, WorldDimension d) =>
          r.dimensions[d]!.score!;
      for (final d in [WorldDimension.time, WorldDimension.mental]) {
        expect(score(moved, d), lessThan(score(before, d)), reason: d.name);
        expect(
          score(protectedRecovery, d),
          lessThan(score(moved, d)),
          reason: d.name,
        );
      }
      expect(moved.totalScore!, lessThan(before.totalScore!));
      expect(protectedRecovery.totalScore!, lessThanOrEqualTo(moved.totalScore!));
    });
  });

  group('Step 6: achievements earned along the journey, and Undo', () {
    const evaluator = AchievementEvaluator();
    final confirm = PlanConfirmationEvent(
      eventId: 'plan-1',
      committed: true,
      outcome: PlanOutcome.confirmed,
      validation: ValidationStatus.feasible,
      protectedCommitmentsIntact: true,
      moves: [
        PlannedMove(
          isFlexible: true,
          newEnd: DateTime(2026, 10, 8, 19, 30),
          dueAt: readingDue,
        ),
        PlannedMove(
          isFlexible: true,
          newEnd: DateTime(2026, 10, 10, 11),
          dueAt: DateTime(2026, 10, 12, 18),
        ),
      ],
    );
    const recovery = RecoverySlotEvent(
      eventId: 'recovery-1',
      committed: true,
      action: RecoveryAction.protectSlot,
      isProtected: true,
    );

    test('Confirm earns Safe Trade-off and Deadline Safety once each', () {
      final awards = evaluator.newAwards([confirm, recovery]);
      expect(awards.map((a) => a.key), [
        AchievementKey.safeTradeOff,
        AchievementKey.deadlineSafety,
        AchievementKey.protectedRest,
      ]);
    });

    test('Undo and a second Confirm change nothing already earned', () {
      final held = {
        AchievementKey.safeTradeOff,
        AchievementKey.deadlineSafety,
        AchievementKey.protectedRest,
      };
      const undone = PlanConfirmationEvent(
        eventId: 'undo-1',
        committed: true,
        outcome: PlanOutcome.rejected,
        validation: ValidationStatus.feasible,
        protectedCommitmentsIntact: true,
      );
      final again = PlanConfirmationEvent(
        eventId: 'plan-2',
        committed: true,
        outcome: PlanOutcome.confirmed,
        validation: ValidationStatus.feasible,
        protectedCommitmentsIntact: true,
        moves: confirm.moves,
      );
      expect(
        evaluator.newAwards([undone, again], alreadyAwarded: held),
        isEmpty,
      );
      expect(held.length, 3);
    });

    test('an early review the day before the Friday deadline qualifies', () {
      final review = OverloadReviewEvent(
        eventId: 'review-1',
        committed: true,
        acknowledged: true,
        hadOverload: true,
        reviewedOn: LocalDate(2026, 10, 5),
        deadlineOn: LocalDate(2026, 10, 9),
      );
      expect(evaluator.eligibleKeys(review), [AchievementKey.earlyReview]);
    });

    test('Team Coordination stays locked without verified shared-task evidence', () {
      const personal = SharedTaskAgreementEvent(
        eventId: 'task-1',
        committed: true,
        isVerifiedShared: false,
        markedNeedsAgreement: true,
        movedAutomatically: false,
      );
      expect(evaluator.newAwards([confirm, recovery, personal]).map((a) => a.key),
          isNot(contains(AchievementKey.teamCoordination)));
    });
  });
}
