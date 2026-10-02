import '../../domain/models/achievement_models.dart';

abstract interface class AchievementRepository {
  Future<AchievementSnapshot> fetchAchievements();
}
