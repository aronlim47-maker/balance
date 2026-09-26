class PlanReservation {
  const PlanReservation({
    required this.taskId,
    required this.startAt,
    required this.endAt,
  });

  final String taskId;
  final DateTime startAt;
  final DateTime endAt;
}
