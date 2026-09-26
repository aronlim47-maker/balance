import '../../domain/models/availability_block.dart';

abstract final class AvailabilityMapper {
  static AvailabilityBlock fromJson(Map<String, dynamic> json) =>
      AvailabilityBlock(
        id: json['id'] as String,
        startAt: DateTime.parse(json['start_at'] as String),
        endAt: DateTime.parse(json['end_at'] as String),
        isAvailable: json['block_type'] == 'available',
        label: json['label'] as String?,
      );

  static Map<String, dynamic> toInsert(
    AvailabilityBlock block,
    String userId,
  ) => {'user_id': userId, ...toUpdate(block)};

  static Map<String, dynamic> toUpdate(AvailabilityBlock block) => {
    'start_at': block.startAt.toUtc().toIso8601String(),
    'end_at': block.endAt.toUtc().toIso8601String(),
    'block_type': block.isAvailable ? 'available' : 'blocked',
    'label': block.label,
  };
}
