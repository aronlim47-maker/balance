class CheckIn {
  const CheckIn({
    required this.date,
    this.id,
    this.sleepHours,
    this.mental,
    this.physical,
    this.social,
    this.errands,
  });

  final String? id;
  final DateTime date;
  final double? sleepHours;
  final int? mental;
  final int? physical;
  final int? social;
  final int? errands;
}
