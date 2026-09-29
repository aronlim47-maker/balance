class MovementSettings {
  const MovementSettings({this.trackingEnabled = false, this.targetDays = 3,
    this.targetRecoveryMinutes = 30, this.targetSocialMinutesWeek = 300})
    : assert(targetDays >= 1 && targetDays <= 14);

  final bool trackingEnabled;
  final int targetDays;
  final int targetRecoveryMinutes;
  final int targetSocialMinutesWeek;
}

class ExerciseLog {
  const ExerciseLog({
    required this.id,
    required this.occurredAt,
    required this.durationMinutes,
    this.taskId,
    this.intensity,
  }) : assert(durationMinutes >= 1 && durationMinutes <= 1440);

  final String id;
  final DateTime occurredAt;
  final int durationMinutes;
  final String? taskId;
  final String? intensity;
}
