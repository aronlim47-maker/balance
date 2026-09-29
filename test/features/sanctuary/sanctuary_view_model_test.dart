import 'package:balance/data/repositories/recovery_repository.dart';
import 'package:balance/domain/models/recovery_slot.dart';
import 'package:balance/features/sanctuary/sanctuary_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual rest saves, overlapping rest is rejected, Council slot is locked', () async {
    final repository = _Recovery();
    final model = SanctuaryViewModel(repository);
    final first = RecoverySlot(id: '', startAt: DateTime(2026, 9, 28, 9),
      endAt: DateTime(2026, 9, 28, 10));
    expect(await model.save(first), isTrue);
    expect(model.slots, hasLength(1));
    expect(await model.save(RecoverySlot(id: '',
      startAt: DateTime(2026, 9, 28, 9, 30),
      endAt: DateTime(2026, 9, 28, 10, 30))), isFalse);
    expect(model.error, contains('overlaps'));
    final council = RecoverySlot(id: 'council', planChangeId: 'plan',
      startAt: DateTime(2026, 9, 28, 11), endAt: DateTime(2026, 9, 28, 12));
    expect(await model.remove(council), isFalse);
    expect(await model.save(council), isFalse);
    model.dispose();
  });
}

class _Recovery implements RecoveryRepository {
  final slots = <RecoverySlot>[];
  @override
  Future<List<RecoverySlot>> fetchRecoverySlots() async => List.of(slots);
  @override
  Future<RecoverySlot> createRecoverySlot(RecoverySlot slot) async {
    final saved = RecoverySlot(id: 'one', startAt: slot.startAt,
      endAt: slot.endAt, selectedActivity: slot.selectedActivity);
    slots.add(saved);
    return saved;
  }
  @override
  Future<RecoverySlot> updateRecoverySlot(RecoverySlot slot) async {
    slots[slots.indexWhere((item) => item.id == slot.id)] = slot;
    return slot;
  }
  @override
  Future<void> deleteRecoverySlot(String id) async => slots.removeWhere((slot) => slot.id == id);
}
