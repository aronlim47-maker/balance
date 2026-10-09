import '../../domain/models/availability_block.dart';

abstract interface class AvailabilityRepository {
  Future<List<AvailabilityBlock>> fetchAvailability();
  Future<AvailabilityBlock> createAvailability(AvailabilityBlock block);
  Future<AvailabilityBlock> updateAvailability(AvailabilityBlock block);
  Future<void> deleteAvailability(String blockId);
}
