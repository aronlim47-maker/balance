import '../../domain/models/recovery_slot.dart';

abstract final class RecoveryMapper {
  static RecoverySlot fromJson(Map<String, dynamic> json) => RecoverySlot(
    id: json['id'] as String,
    startAt: DateTime.parse(json['start_at'] as String),
    endAt: DateTime.parse(json['end_at'] as String),
    isProtected: json['is_protected'] as bool? ?? true,
    planChangeId: json['plan_change_id'] as String?,
    selectedActivity: json['selected_activity'] as String?,
    completedAt: json['completed_at'] == null
        ? null
        : DateTime.parse(json['completed_at'] as String),
  );

  static Map<String, dynamic> toInsert(RecoverySlot slot, String userId) => {
    'user_id': userId,
    ...toUpdate(slot),
  };

  static Map<String, dynamic> toUpdate(RecoverySlot slot) => {
    'start_at': slot.startAt.toUtc().toIso8601String(),
    'end_at': slot.endAt.toUtc().toIso8601String(),
    'is_protected': slot.isProtected,
    'selected_activity': slot.selectedActivity,
    'completed_at': slot.completedAt?.toUtc().toIso8601String(),
  };
}
