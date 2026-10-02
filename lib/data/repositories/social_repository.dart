import '../../domain/models/social_event_record.dart';

abstract interface class SocialRepository {
  Future<List<SocialEventRecord>> fetchEventsForWeek(DateTime day);
  Future<bool> fetchNoCommitmentsForWeek(DateTime day);
  Future<void> saveNoCommitmentsForWeek(DateTime day, bool noCommitments);
  /// Creates the event and clears its week's no-commitments response atomically.
  Future<SocialEventRecord> createEvent(SocialEventRecord event);
  Future<void> deleteEvent(String id);
}
