import '../../domain/enums/plan_status.dart';
import '../../domain/enums/validation_status.dart';
import '../../domain/models/plan_change.dart';

abstract final class PlanMapper {
  static PlanChange fromJson(Map<String, dynamic> json) => PlanChange(
    id: json['id'] as String,
    status: _status(json['status'] as String),
    beforeOverloadMinutes:
        (json['before_overload_minutes'] as num?)?.toInt() ?? 0,
    afterOverloadMinutes:
        (json['after_overload_minutes'] as num?)?.toInt() ?? 0,
    validationStatus: _validationStatus(
      json['validation_status'] as String? ?? 'needs_review',
    ),
    consequences: Map<String, dynamic>.from(
      json['consequences'] as Map? ?? const <String, dynamic>{},
    ),
    failureReason: json['failure_reason'] as String?,
    confirmedAt: _dateTime(json['confirmed_at']),
    undoneAt: _dateTime(json['undone_at']),
    createdAt: _dateTime(json['created_at']),
  );

  static DateTime? _dateTime(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  static PlanStatus _status(String value) => switch (value) {
    'confirmed' => PlanStatus.confirmed,
    'undone' => PlanStatus.undone,
    _ => PlanStatus.draft,
  };

  static ValidationStatus _validationStatus(String value) => switch (value) {
    'feasible' => ValidationStatus.feasible,
    'needs_agreement' => ValidationStatus.needsAgreement,
    'no_feasible_plan' => ValidationStatus.noFeasiblePlan,
    _ => ValidationStatus.needsReview,
  };
}
