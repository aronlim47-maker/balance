import 'package:balance/domain/enums/validation_status.dart';
import 'package:balance/domain/models/achievement_models.dart';
import 'package:balance/domain/models/local_date.dart';
import 'package:balance/domain/usecases/achievement_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Positive and negative fixtures for the seven achievement_v1 rules
/// (Balance Build Phase Plan 14.7 and 14.7.1).
void main() {
  const evaluator = AchievementEvaluator();
  final due = DateTime(2026, 10, 9, 17);

  bool eligible(AchievementKey key, AchievementEvent event) =>
      evaluator.decide(key, event).eligible;

  RecoverySlotEvent slot({
    RecoveryAction action = RecoveryAction.protectSlot,
    bool isProtected = true,
    bool committed = true,
    String id = 'slot-1',
  }) => RecoverySlotEvent(
    eventId: id,
    committed: committed,
    action: action,
    isProtected: isProtected,
  );

  CommitmentProtectionEvent commitment({
    CommitmentType? type = CommitmentType.workShift,
    bool isProtected = true,
    bool committed = true,
    String id = 'task-1',
  }) => CommitmentProtectionEvent(
    eventId: id,
    committed: committed,
    isProtected: isProtected,
    commitmentType: type,
  );

  PlanConfirmationEvent plan({
    PlanOutcome outcome = PlanOutcome.confirmed,
    ValidationStatus validation = ValidationStatus.feasible,
    bool intact = true,
    bool committed = true,
    List<PlannedMove>? moves,
    String id = 'plan-1',
  }) => PlanConfirmationEvent(
    eventId: id,
    committed: committed,
    outcome: outcome,
    validation: validation,
    protectedCommitmentsIntact: intact,
    moves: moves ?? const [],
  );

  PlannedMove move({bool flexible = true, DateTime? end}) =>
      PlannedMove(isFlexible: flexible, newEnd: end ?? due, dueAt: due);

  OverloadReviewEvent review({
    bool acknowledged = true,
    bool overload = true,
    LocalDate? reviewedOn,
    LocalDate? deadlineOn,
    bool committed = true,
    String id = 'review-1',
  }) => OverloadReviewEvent(
    eventId: id,
    committed: committed,
    acknowledged: acknowledged,
    hadOverload: overload,
    reviewedOn: reviewedOn ?? LocalDate(2026, 10, 8),
    deadlineOn: deadlineOn ?? LocalDate(2026, 10, 9),
  );

  ReflectionEvent reflection({
    bool submitted = true,
    String? body = 'A busy but manageable week.',
    bool committed = true,
    String id = 'reflection-1',
  }) => ReflectionEvent(
    eventId: id,
    committed: committed,
    submitted: submitted,
    body: body,
  );

  SharedTaskAgreementEvent shared({
    bool verified = true,
    bool marked = true,
    bool movedAutomatically = false,
    bool committed = true,
    String id = 'shared-1',
  }) => SharedTaskAgreementEvent(
    eventId: id,
    committed: committed,
    isVerifiedShared: verified,
    markedNeedsAgreement: marked,
    movedAutomatically: movedAutomatically,
  );

  group('commitment type storage values', () {
    test('match the database check constraint and round-trip', () {
      expect(CommitmentType.values.map((t) => t.storageValue), [
        'work_shift',
        'family_duty',
        'sleep_minimum',
      ]);
      for (final type in CommitmentType.values) {
        expect(CommitmentType.fromStorage(type.storageValue), type);
      }
    });
    test('anything else is no commitment type, never inferred from a title', () {
      expect(CommitmentType.fromStorage(null), isNull);
      expect(CommitmentType.fromStorage(''), isNull);
      expect(CommitmentType.fromStorage('Work shift'), isNull);
    });
  });

  group('catalogue', () {
    test('keys match the seven persisted achievement_v1 keys', () {
      expect(
        AchievementKey.values.map((k) => k.key).toList(),
        achievementV1Catalogue.map((d) => d.key).toList(),
      );
      expect(AchievementKey.values.length, 7);
      expect(AchievementEvaluator.ruleVersion, 'achievement_v1');
    });
  });

  group('Protected Rest', () {
    test('positive: protecting a sleep or recovery slot', () {
      expect(eligible(AchievementKey.protectedRest, slot()), isTrue);
    });
    test('positive: protecting a sleep minimum also counts', () {
      expect(
        eligible(
          AchievementKey.protectedRest,
          commitment(type: CommitmentType.sleepMinimum),
        ),
        isTrue,
      );
    });
    test('negative: choosing, completing, viewing or previewing', () {
      for (final action in RecoveryAction.values) {
        if (action == RecoveryAction.protectSlot) continue;
        expect(
          eligible(AchievementKey.protectedRest, slot(action: action)),
          isFalse,
          reason: action.name,
        );
      }
    });
    test('negative: unprotected slot, work shift alone, unsaved action', () {
      expect(
        eligible(AchievementKey.protectedRest, slot(isProtected: false)),
        isFalse,
      );
      expect(
        eligible(
          AchievementKey.protectedRest,
          commitment(type: CommitmentType.workShift),
        ),
        isFalse,
      );
      expect(
        eligible(AchievementKey.protectedRest, slot(committed: false)),
        isFalse,
      );
    });
  });

  group('Safe Trade-off', () {
    test('positive: committed, feasible, protected items intact', () {
      expect(eligible(AchievementKey.safeTradeOff, plan()), isTrue);
    });
    test('negative: preview, rejected proposal and failed transaction', () {
      for (final outcome in [
        PlanOutcome.previewed,
        PlanOutcome.rejected,
        PlanOutcome.failed,
      ]) {
        expect(
          eligible(AchievementKey.safeTradeOff, plan(outcome: outcome)),
          isFalse,
          reason: outcome.name,
        );
      }
      expect(
        eligible(AchievementKey.safeTradeOff, plan(committed: false)),
        isFalse,
      );
    });
    test('negative: not feasible, or a protected commitment was broken', () {
      for (final status in [
        ValidationStatus.needsReview,
        ValidationStatus.needsAgreement,
        ValidationStatus.noFeasiblePlan,
      ]) {
        expect(
          eligible(AchievementKey.safeTradeOff, plan(validation: status)),
          isFalse,
          reason: status.name,
        );
      }
      expect(
        eligible(AchievementKey.safeTradeOff, plan(intact: false)),
        isFalse,
      );
    });
  });

  group('Deadline Safety', () {
    test('positive: a flexible task moved and its deadline is safe', () {
      expect(
        eligible(
          AchievementKey.deadlineSafety,
          plan(moves: [move(end: due.subtract(const Duration(hours: 1)))]),
        ),
        isTrue,
      );
      // Finishing exactly at the deadline is still safe.
      expect(
        eligible(AchievementKey.deadlineSafety, plan(moves: [move(end: due)])),
        isTrue,
      );
    });
    test('negative: no move, only a fixed task moved, or past the deadline', () {
      expect(eligible(AchievementKey.deadlineSafety, plan()), isFalse);
      expect(
        eligible(
          AchievementKey.deadlineSafety,
          plan(moves: [move(flexible: false)]),
        ),
        isFalse,
      );
      expect(
        eligible(
          AchievementKey.deadlineSafety,
          plan(moves: [move(end: due.add(const Duration(minutes: 1)))]),
        ),
        isFalse,
      );
    });
    test('negative: an unconfirmed or failed plan never qualifies', () {
      expect(
        eligible(
          AchievementKey.deadlineSafety,
          plan(outcome: PlanOutcome.previewed, moves: [move()]),
        ),
        isFalse,
      );
      expect(
        eligible(
          AchievementKey.deadlineSafety,
          plan(committed: false, moves: [move()]),
        ),
        isFalse,
      );
    });
  });

  group('Early Review', () {
    test('positive: acknowledged the day before the deadline', () {
      expect(eligible(AchievementKey.earlyReview, review()), isTrue);
    });
    test('negative: same-day review is rejected', () {
      expect(
        eligible(
          AchievementKey.earlyReview,
          review(
            reviewedOn: LocalDate(2026, 10, 9),
            deadlineOn: LocalDate(2026, 10, 9),
          ),
        ),
        isFalse,
      );
    });
    test('negative: after the deadline, no deadline, no overload, no ack', () {
      expect(
        eligible(
          AchievementKey.earlyReview,
          review(reviewedOn: LocalDate(2026, 10, 10)),
        ),
        isFalse,
      );
      final noDeadline = OverloadReviewEvent(
        eventId: 'r',
        committed: true,
        acknowledged: true,
        hadOverload: true,
        reviewedOn: LocalDate(2026, 10, 8),
        deadlineOn: null,
      );
      expect(eligible(AchievementKey.earlyReview, noDeadline), isFalse);
      expect(
        eligible(AchievementKey.earlyReview, review(overload: false)),
        isFalse,
      );
      expect(
        eligible(AchievementKey.earlyReview, review(acknowledged: false)),
        isFalse,
      );
      expect(
        eligible(AchievementKey.earlyReview, review(committed: false)),
        isFalse,
      );
    });
  });

  group('Protected Limit', () {
    test('positive: work shift, family duty and sleep minimum', () {
      for (final type in CommitmentType.values) {
        expect(
          eligible(AchievementKey.protectedLimit, commitment(type: type)),
          isTrue,
          reason: type.name,
        );
      }
    });
    test('negative: protected task without a recorded commitment type', () {
      expect(
        eligible(AchievementKey.protectedLimit, commitment(type: null)),
        isFalse,
      );
    });
    test('negative: not protected, unsaved, or a recovery slot', () {
      expect(
        eligible(
          AchievementKey.protectedLimit,
          commitment(isProtected: false),
        ),
        isFalse,
      );
      expect(
        eligible(AchievementKey.protectedLimit, commitment(committed: false)),
        isFalse,
      );
      expect(eligible(AchievementKey.protectedLimit, slot()), isFalse);
    });
  });

  group('Reflection', () {
    test('positive: a non-empty voluntary submission', () {
      expect(eligible(AchievementKey.reflection, reflection()), isTrue);
    });
    test('negative: opened, skipped or cancelled', () {
      expect(
        eligible(AchievementKey.reflection, reflection(submitted: false)),
        isFalse,
      );
    });
    test('negative: empty, whitespace-only, null or unsaved', () {
      for (final body in ['', '   \n\t', null]) {
        expect(
          eligible(AchievementKey.reflection, reflection(body: body)),
          isFalse,
          reason: '$body',
        );
      }
      expect(
        eligible(AchievementKey.reflection, reflection(committed: false)),
        isFalse,
      );
    });
    test('a gloomy reflection still qualifies (no positive-mood rule)', () {
      expect(
        eligible(
          AchievementKey.reflection,
          reflection(body: 'This week was hard.'),
        ),
        isTrue,
      );
    });
  });

  group('Team Coordination', () {
    test('positive: verified shared task marked Needs Agreement', () {
      expect(eligible(AchievementKey.teamCoordination, shared()), isTrue);
    });
    test('positive: does not wait for approval (none is modelled)', () {
      // The valid Needs Agreement record alone is enough.
      expect(eligible(AchievementKey.teamCoordination, shared()), isTrue);
    });
    test('negative: personal task, label only, or not marked', () {
      expect(
        eligible(AchievementKey.teamCoordination, shared(verified: false)),
        isFalse,
      );
      expect(
        eligible(AchievementKey.teamCoordination, shared(marked: false)),
        isFalse,
      );
    });
    test('negative: moved automatically, or not saved', () {
      expect(
        eligible(
          AchievementKey.teamCoordination,
          shared(movedAutomatically: true),
        ),
        isFalse,
      );
      expect(
        eligible(AchievementKey.teamCoordination, shared(committed: false)),
        isFalse,
      );
    });
  });

  group('cross-checks', () {
    test('each event type qualifies only for its own achievements', () {
      expect(evaluator.eligibleKeys(slot()), [AchievementKey.protectedRest]);
      expect(evaluator.eligibleKeys(reflection()), [AchievementKey.reflection]);
      expect(evaluator.eligibleKeys(review()), [AchievementKey.earlyReview]);
      expect(evaluator.eligibleKeys(shared()), [
        AchievementKey.teamCoordination,
      ]);
      expect(evaluator.eligibleKeys(commitment()), [
        AchievementKey.protectedLimit,
      ]);
      expect(
        evaluator.eligibleKeys(commitment(type: CommitmentType.sleepMinimum)),
        [AchievementKey.protectedRest, AchievementKey.protectedLimit],
      );
      expect(evaluator.eligibleKeys(plan(moves: [move()])), [
        AchievementKey.safeTradeOff,
        AchievementKey.deadlineSafety,
      ]);
    });

    test('an unsaved event qualifies for nothing', () {
      expect(evaluator.eligibleKeys(plan(committed: false)), isEmpty);
      expect(evaluator.eligibleKeys(slot(committed: false)), isEmpty);
    });

    test('the decision explains itself in plain English', () {
      final decision = evaluator.decide(
        AchievementKey.earlyReview,
        review(
          reviewedOn: LocalDate(2026, 10, 9),
          deadlineOn: LocalDate(2026, 10, 9),
        ),
      );
      expect(decision.eligible, isFalse);
      expect(decision.reason, contains('before the deadline'));
      expect(decision.toString(), contains('early_review'));
    });
  });

  group('once-per-type awards', () {
    test('repeated taps / retries of one event award once', () {
      final awards = evaluator.newAwards([
        reflection(id: 'same'),
        reflection(id: 'same'),
      ]);
      expect(awards.map((a) => a.key), [AchievementKey.reflection]);
      expect(awards.single.eventId, 'same');
    });

    test('a second qualifying event of the same type earns nothing new', () {
      final awards = evaluator.newAwards([
        reflection(id: 'first'),
        reflection(id: 'second'),
      ]);
      expect(awards.length, 1);
      expect(awards.single.eventId, 'first');
    });

    test('already-held achievements are not awarded again', () {
      final awards = evaluator.newAwards(
        [reflection(), slot()],
        alreadyAwarded: {AchievementKey.reflection},
      );
      expect(awards.map((a) => a.key), [AchievementKey.protectedRest]);
    });

    test('a later failed or previewed plan never removes or re-earns', () {
      final held = {AchievementKey.safeTradeOff};
      final awards = evaluator.newAwards([
        plan(id: 'undo-like', outcome: PlanOutcome.failed),
        plan(id: 'again', moves: [move()]),
      ], alreadyAwarded: held);
      // Safe Trade-off is already held; only Deadline Safety is new.
      expect(awards.map((a) => a.key), [AchievementKey.deadlineSafety]);
      expect(held, {AchievementKey.safeTradeOff});
    });

    test('all seven can be earned from one realistic history', () {
      final awards = evaluator.newAwards([
        slot(id: 'a'),
        commitment(id: 'b', type: CommitmentType.familyDuty),
        plan(id: 'c', moves: [move()]),
        review(id: 'd'),
        reflection(id: 'e'),
        shared(id: 'f'),
      ]);
      expect(
        awards.map((a) => a.key).toSet(),
        AchievementKey.values.toSet(),
      );
      expect(awards.length, 7);
    });
  });
}
