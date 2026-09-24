class AvailabilityBlock {
  const AvailabilityBlock({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.isAvailable,
  });
  final String id;
  final DateTime startAt;
  final DateTime endAt;
  final bool isAvailable;
}
