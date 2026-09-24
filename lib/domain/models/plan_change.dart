import '../enums/plan_status.dart';

class PlanChange {
  const PlanChange({required this.id, this.status = PlanStatus.draft});
  final String id;
  final PlanStatus status;
}
