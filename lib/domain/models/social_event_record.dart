import '../usecases/world_status_calculator.dart';

class SocialEventRecord {
  SocialEventRecord({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.pressure,
    this.taskId,
  }) : assert(endAt.isAfter(startAt));

  final String id;
  final DateTime startAt;
  final DateTime endAt;
  final SocialPressure pressure;
  final String? taskId;

  WorldSocialEvent toWorldStatusEvent() => WorldSocialEvent(
    durationMinutes: endAt.difference(startAt).inMinutes,
    pressure: pressure,
  );
}
