import '../enums/plan_status.dart';
import '../enums/validation_status.dart';

class PlanChange {
  const PlanChange({
    required this.id,
    this.status = PlanStatus.draft,
    this.beforeOverloadMinutes = 0,
    this.afterOverloadMinutes = 0,
    this.validationStatus = ValidationStatus.needsReview,
    this.consequences = const <String, dynamic>{},
    this.failureReason,
    this.confirmedAt,
    this.undoneAt,
    this.createdAt,
  });

  final String id;
  final PlanStatus status;
  final int beforeOverloadMinutes;
  final int afterOverloadMinutes;
  final ValidationStatus validationStatus;
  final Map<String, dynamic> consequences;
  final String? failureReason;
  final DateTime? confirmedAt;
  final DateTime? undoneAt;
  final DateTime? createdAt;
}
