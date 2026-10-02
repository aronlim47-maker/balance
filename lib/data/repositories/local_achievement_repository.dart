import '../../domain/models/achievement_models.dart';
import 'achievement_repository.dart';

class LocalAchievementRepository implements AchievementRepository {
  @override
  Future<AchievementSnapshot> fetchAchievements() async =>
      const AchievementSnapshot(
        definitions: achievementV1Catalogue,
        awards: [],
      );
}
