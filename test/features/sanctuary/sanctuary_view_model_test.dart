import 'package:balance/data/repositories/recovery_repository.dart';
import 'package:balance/domain/models/recovery_slot.dart';
import 'package:balance/features/sanctuary/sanctuary_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'manual rest saves, overlapping rest is rejected, Council slot is locked',
        () async {
      final repository = _Recovery();
      final model = SanctuaryViewModel(repository);
      final first = RecoverySlot(
        id: '',
        startAt: DateTime(2026, 9, 28, 9),
        endAt: DateTime(2026, 9, 28, 10),
      );
      expect(await model.save(first), isTrue);
      expect(model.slots, hasLength(1));
      expect(
        await model.save(
          RecoverySlot(
            id: '',
            startAt: DateTime(2026, 9, 28, 9, 30),
            endAt: DateTime(2026, 9, 28, 10, 30),
          ),
        ),
        isFalse,
      );
      expect(model.error, contains('overlaps'));
      final council = RecoverySlot(
        id: 'council',
        planChangeId: 'plan',
        startAt: DateTime(2026, 9, 28, 11),
        endAt: DateTime(2026, 9, 28, 12),
      );
      expect(await model.remove(council), isFalse);
      expect(await model.save(council), isFalse);
      model.dispose();
    },
  );

  test(
    'a successful write reports a refresh failure without asking to save again',
        () async {
      final repository = _Recovery()..failReads = true;
      final model = SanctuaryViewModel(repository);
      final slot = RecoverySlot(
        id: '',
        startAt: DateTime(2026, 9, 28, 9),
        endAt: DateTime(2026, 9, 28, 10),
      );

      expect(await model.save(slot), isTrue);
      expect(repository.slots, hasLength(1));
      expect(model.error, contains('saved, but'));

      repository.failReads = false;
      await model.load();
      expect(model.error, isNull);
      expect(model.slots, hasLength(1));
      model.dispose();
    },
  );

  test(
    'a failed write is reported as a failure, not a refresh warning',
        () async {
      final repository = _Recovery()..failWrites = true;
      final model = SanctuaryViewModel(repository);
      final slot = RecoverySlot(
        id: '',
        startAt: DateTime(2026, 9, 28, 9),
        endAt: DateTime(2026, 9, 28, 10),
      );

      expect(await model.save(slot), isFalse);
      expect(repository.slots, isEmpty);
      expect(model.error, isNot(contains('saved, but')));
      model.dispose();
    },
  );

  _activityDoneTests();
}

void _activityDoneTests() {
  test('marking an activity done only sets completedAt and can be undone',
          () async {
        final repository = _Recovery();
        final model = SanctuaryViewModel(repository);
        final past = DateTime.now().subtract(const Duration(hours: 2));
        expect(
          await model.save(
            RecoverySlot(
              id: '',
              startAt: past,
              endAt: past.add(const Duration(minutes: 30)),
              selectedActivity: 'Short walk',
            ),
          ),
          isTrue,
        );
        final slot = model.slots.single;

        expect(await model.setActivityDone(slot, done: true), isTrue);
        final done = repository.slots.single;
        expect(done.completedAt, isNotNull);
        expect(done.startAt, slot.startAt);
        expect(done.endAt, slot.endAt);
        expect(done.selectedActivity, 'Short walk');

        expect(await model.setActivityDone(done, done: false), isTrue);
        expect(repository.slots.single.completedAt, isNull);
        model.dispose();
      });

  test('future and Council slots cannot be marked done here', () async {
    final repository = _Recovery();
    final model = SanctuaryViewModel(repository);
    final future = DateTime.now().add(const Duration(days: 1));
    final upcoming = RecoverySlot(
      id: 'later',
      startAt: future,
      endAt: future.add(const Duration(minutes: 30)),
      selectedActivity: 'Short walk',
    );
    expect(await model.setActivityDone(upcoming, done: true), isFalse);
    expect(model.error, contains('started'));

    final council = RecoverySlot(
      id: 'council',
      planChangeId: 'plan',
      startAt: DateTime(2026, 9, 28, 11),
      endAt: DateTime(2026, 9, 28, 12),
    );
    expect(await model.setActivityDone(council, done: true), isFalse);
    expect(model.error, contains('Council'));
    model.dispose();
  });
}

class _Recovery implements RecoveryRepository {
  final slots = <RecoverySlot>[];
  bool failReads = false;
  bool failWrites = false;
  @override
  Future<List<RecoverySlot>> fetchRecoverySlots() async {
    if (failReads) throw StateError('Simulated read failure');
    return List.of(slots);
  }

  @override
  Future<RecoverySlot> createRecoverySlot(RecoverySlot slot) async {
    if (failWrites) throw StateError('Simulated write failure');
    final saved = RecoverySlot(
      id: 'one',
      startAt: slot.startAt,
      endAt: slot.endAt,
      selectedActivity: slot.selectedActivity,
    );
    slots.add(saved);
    return saved;
  }

  @override
  Future<RecoverySlot> updateRecoverySlot(RecoverySlot slot) async {
    slots[slots.indexWhere((item) => item.id == slot.id)] = slot;
    return slot;
  }

  @override
  Future<void> deleteRecoverySlot(String id) async =>
      slots.removeWhere((slot) => slot.id == id);
}
