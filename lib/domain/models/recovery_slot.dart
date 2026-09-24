class RecoverySlot {
  const RecoverySlot({
    required this.id,
    required this.startAt,
    required this.endAt,
    this.isProtected = true,
  });
  final String id;
  final DateTime startAt;
  final DateTime endAt;
  final bool isProtected;
}
