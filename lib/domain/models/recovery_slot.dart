class RecoverySlot {
  const RecoverySlot({
    required this.id,
    required this.startAt,
    required this.endAt,
    this.isProtected = true,
    this.planChangeId,
    this.selectedActivity,
    this.completedAt,
  });
  final String id;
  final DateTime startAt;
  final DateTime endAt;
  final bool isProtected;
  final String? planChangeId;
  final String? selectedActivity;
  final DateTime? completedAt;
}
