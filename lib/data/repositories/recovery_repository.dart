import '../../domain/models/recovery_slot.dart';

abstract interface class RecoveryRepository {
  Future<List<RecoverySlot>> fetchRecoverySlots();
  Future<RecoverySlot> createRecoverySlot(RecoverySlot slot);
  Future<RecoverySlot> updateRecoverySlot(RecoverySlot slot);
  Future<void> deleteRecoverySlot(String slotId);
}
