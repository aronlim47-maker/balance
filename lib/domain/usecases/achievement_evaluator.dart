import '../enums/validation_status.dart';
import '../models/local_date.dart';

/// Stable achievement keys. These strings are the persisted identifiers in
/// `achievement_v1` (see `achievementV1Catalogue` and the SQL catalogue); a
/// wording change to a label must never change a key.
enum AchievementKey {
  protectedRest('protected_rest'),
  safeTradeOff('safe_trade_off'),
  deadlineSafety('deadline_safety'),
  earlyReview('early_review'),
  protectedLimit('protected_limit'),
  reflection('reflection'),
  teamCoordination('team_coordination');

  const AchievementKey(this.key);
  final String key;
}

/// Why an event did or did not qualify, in plain English for evidence and
/// for tests. It is never a client-supplied "isEligible" flag: eligibility is
/// always computed from the facts carried by the event.
class AchievementDecision {
  const AchievementDecision(this.key, this.eligible, this.reason);
  final AchievementKey key;
  final bool eligible;
  final String reason;

  @override
  String toString() => '${key.key}: ${eligible ? 'eligible' : 'no'} ($reason)';
}

/// A pair that says which event first earned which achievement.
class EarnedAchievement {
  const EarnedAchievement(this.key, this.eventId);
  final AchievementKey key;
  final String eventId;
}

/// A stable, already-committed fact about what the user did.
///
/// [eventId] must be stable across retries and devices (for example the
/// database row id of the recovery slot, plan change or reflection) so the
/// same action can never be counted twice. [committed] is true only after the
/// action was successfully persisted; nothing qualifies before that
/// (14.7.1: "Never show Unlocked before persistence succeeds").
sealed class AchievementEvent {
  const AchievementEvent({required this.eventId, required this.committed});
  final String eventId;
  final bool committed;
}

/// What the user did with a recovery slot.
enum RecoveryAction {
  /// Protection for a real sleep or recovery slot was saved. Only this action
  /// can qualify.
  protectSlot,
  chooseActivity,
  completeActivity,
  viewSanctuary,
  previewFreeTime,
}

/// A recovery or sleep slot action (Protected Rest).
class RecoverySlotEvent extends AchievementEvent {
  const RecoverySlotEvent({
    required super.eventId,
    required super.committed,
    required this.action,
    required this.isProtected,
  });
  final RecoveryAction action;
  final bool isProtected;
}

/// Commitment kinds that count for Protected Limit. Use the recorded type;
/// never infer it from a free-text title.
enum CommitmentType {
  workShift('work_shift'),
  familyDuty('family_duty'),
  sleepMinimum('sleep_minimum');

  const CommitmentType(this.storageValue);

  /// The persisted value of `tasks.protected_commitment_type`
  /// (also `TaskItem.protectedCommitmentType`).
  final String storageValue;

  /// `null` for no commitment type or any value the database does not allow.
  static CommitmentType? fromStorage(String? value) {
    for (final type in values) {
      if (type.storageValue == value) return type;
    }
    return null;
  }
}

/// Protection being recorded on a task (Protected Limit; a sleep minimum also
/// counts as Protected Rest, matching the database rule).
class CommitmentProtectionEvent extends AchievementEvent {
  const CommitmentProtectionEvent({
    required super.eventId,
    required super.committed,
    required this.isProtected,
    required this.commitmentType,
  });
  final bool isProtected;

  /// `null` for an ordinary protected task with no recorded commitment type.
  final CommitmentType? commitmentType;
}

/// One task that a plan moved.
class PlannedMove {
  const PlannedMove({
    required this.isFlexible,
    required this.newEnd,
    required this.dueAt,
  });
  final bool isFlexible;
  final DateTime newEnd;
  final DateTime dueAt;

  bool get keepsDeadline => !newEnd.isAfter(dueAt);
}

/// Outcome of a plan the user acted on.
enum PlanOutcome { previewed, rejected, failed, confirmed }

/// A plan confirmation attempt (Safe Trade-off, Deadline Safety).
class PlanConfirmationEvent extends AchievementEvent {
  const PlanConfirmationEvent({
    required super.eventId,
    required super.committed,
    required this.outcome,
    required this.validation,
    required this.protectedCommitmentsIntact,
    this.moves = const [],
  });
  final PlanOutcome outcome;
  final ValidationStatus validation;
  final bool protectedCommitmentsIntact;
  final List<PlannedMove> moves;
}

/// An explicit "Mark as reviewed" on an identified overload (Early Review).
class OverloadReviewEvent extends AchievementEvent {
  const OverloadReviewEvent({
    required super.eventId,
    required super.committed,
    required this.acknowledged,
    required this.hadOverload,
    required this.reviewedOn,
    required this.deadlineOn,
  });

  /// False for merely opening the screen.
  final bool acknowledged;
  final bool hadOverload;

  /// Local calendar dates, never instants: 09:00 on the deadline day is still
  /// the deadline day.
  final LocalDate reviewedOn;
  final LocalDate? deadlineOn;
}

/// A reflection the user chose to save (Reflection).
class ReflectionEvent extends AchievementEvent {
  const ReflectionEvent({
    required super.eventId,
    required super.committed,
    required this.submitted,
    required this.body,
  });

  /// False for opening the form, skipping or cancelling.
  final bool submitted;
  final String? body;
}

/// A shared task marked Needs Agreement (Team Coordination; Version 2).
class SharedTaskAgreementEvent extends AchievementEvent {
  const SharedTaskAgreementEvent({
    required super.eventId,
    required super.committed,
    required this.isVerifiedShared,
    required this.markedNeedsAgreement,
    required this.movedAutomatically,
  });

  /// True only when server-side shared-task records prove the task is shared.
  /// A label or a personal task is never enough.
  final bool isVerifiedShared;
  final bool markedNeedsAgreement;
  final bool movedAutomatically;
}

/// Pure, deterministic eligibility rules for the seven `achievement_v1`
/// achievements. No I/O, clock or randomness: the same event always gives the
/// same answer, so every rule has positive and negative fixtures.
///
/// This class decides *eligibility* only. Persistence and once-per-type
/// de-duplication are enforced by the database (`UNIQUE(user_id,
/// achievement_key)`); [newAwards] mirrors that rule so it can be tested.
class AchievementEvaluator {
  const AchievementEvaluator();

  static const ruleVersion = 'achievement_v1';

  /// Decision for one [key] on one [event]. An event of an unrelated type
  /// is simply not eligible.
  AchievementDecision decide(AchievementKey key, AchievementEvent event) {
    AchievementDecision yes(String why) => AchievementDecision(key, true, why);
    AchievementDecision no(String why) => AchievementDecision(key, false, why);

    if (!event.committed) {
      return no('The action has not been saved yet.');
    }
    switch (key) {
      case AchievementKey.protectedRest:
        return switch (event) {
          RecoverySlotEvent e when e.action != RecoveryAction.protectSlot =>
            no('Only protecting a slot qualifies, not ${e.action.name}.'),
          RecoverySlotEvent e when !e.isProtected => no(
            'The slot is not protected.',
          ),
          RecoverySlotEvent _ => yes('A sleep or recovery slot was protected.'),
          CommitmentProtectionEvent e
              when e.isProtected &&
                  e.commitmentType == CommitmentType.sleepMinimum =>
            yes('A sleep minimum was protected.'),
          _ => no('Not a sleep or recovery protection.'),
        };
      case AchievementKey.protectedLimit:
        return switch (event) {
          CommitmentProtectionEvent e when !e.isProtected => no(
            'The commitment is not protected.',
          ),
          CommitmentProtectionEvent e when e.commitmentType == null => no(
            'A protected task needs a recorded commitment type.',
          ),
          CommitmentProtectionEvent e => yes(
            'A ${e.commitmentType!.name} was protected.',
          ),
          _ => no('Not a commitment protection.'),
        };
      case AchievementKey.safeTradeOff:
        return switch (event) {
          PlanConfirmationEvent e => _isSafeConfirmation(e)
              ? yes('A plan was confirmed without breaking protected items.')
              : no(_whyNotSafe(e)),
          _ => no('Not a plan confirmation.'),
        };
      case AchievementKey.deadlineSafety:
        return switch (event) {
          PlanConfirmationEvent e when !_isSafeConfirmation(e) => no(
            _whyNotSafe(e),
          ),
          PlanConfirmationEvent e => _flexibleMoves(e).isEmpty
              ? no('No flexible task was moved.')
              : _flexibleMoves(e).every((m) => m.keepsDeadline)
              ? yes('A flexible task moved and its deadline stayed safe.')
              : no('A moved task would miss its deadline.'),
          _ => no('Not a plan confirmation.'),
        };
      case AchievementKey.earlyReview:
        return switch (event) {
          OverloadReviewEvent e when !e.acknowledged => no(
            'Opening the screen is not a review.',
          ),
          OverloadReviewEvent e when !e.hadOverload => no(
            'There was no identified overload.',
          ),
          OverloadReviewEvent e when e.deadlineOn == null => no(
            'No related deadline.',
          ),
          OverloadReviewEvent e when e.reviewedOn.compareTo(e.deadlineOn!) >=
              0 =>
            no('The review must be before the deadline day.'),
          OverloadReviewEvent _ => yes('An overload was reviewed early.'),
          _ => no('Not an overload review.'),
        };
      case AchievementKey.reflection:
        return switch (event) {
          ReflectionEvent e when !e.submitted => no(
            'Opening, skipping or cancelling does not count.',
          ),
          ReflectionEvent e when (e.body ?? '').trim().isEmpty => no(
            'The reflection is empty.',
          ),
          ReflectionEvent _ => yes('A reflection was saved.'),
          _ => no('Not a reflection.'),
        };
      case AchievementKey.teamCoordination:
        return switch (event) {
          SharedTaskAgreementEvent e when !e.isVerifiedShared => no(
            'The task is not a verified shared task.',
          ),
          SharedTaskAgreementEvent e when !e.markedNeedsAgreement => no(
            'The task was not marked Needs Agreement.',
          ),
          SharedTaskAgreementEvent e when e.movedAutomatically => no(
            'The task was moved automatically.',
          ),
          SharedTaskAgreementEvent _ => yes(
            'A shared task was marked Needs Agreement.',
          ),
          _ => no('Not a shared-task agreement.'),
        };
    }
  }

  /// Every key [event] qualifies for, in catalogue order.
  List<AchievementKey> eligibleKeys(AchievementEvent event) => [
    for (final key in AchievementKey.values)
      if (decide(key, event).eligible) key,
  ];

  /// The awards that should be created when [events] (oldest first) are
  /// processed for a user who already holds [alreadyAwarded].
  ///
  /// Mirrors the once-per-type rule: each key is awarded at most once, a
  /// repeated [AchievementEvent.eventId] (retry, double tap, second device)
  /// is processed once, and an earlier award is never removed.
  List<EarnedAchievement> newAwards(
    Iterable<AchievementEvent> events, {
    Set<AchievementKey> alreadyAwarded = const {},
  }) {
    final held = {...alreadyAwarded};
    final seenEvents = <String>{};
    final awards = <EarnedAchievement>[];
    for (final event in events) {
      if (!seenEvents.add(event.eventId)) continue;
      for (final key in eligibleKeys(event)) {
        if (held.add(key)) awards.add(EarnedAchievement(key, event.eventId));
      }
    }
    return awards;
  }

  static bool _isSafeConfirmation(PlanConfirmationEvent e) =>
      e.outcome == PlanOutcome.confirmed &&
      e.validation == ValidationStatus.feasible &&
      e.protectedCommitmentsIntact;

  static String _whyNotSafe(PlanConfirmationEvent e) {
    if (e.outcome != PlanOutcome.confirmed) {
      return 'A ${e.outcome.name} plan does not qualify.';
    }
    if (e.validation != ValidationStatus.feasible) {
      return 'The plan was not validated as feasible.';
    }
    return 'A protected commitment was broken.';
  }

  static List<PlannedMove> _flexibleMoves(PlanConfirmationEvent e) =>
      e.moves.where((m) => m.isFlexible).toList();
}
