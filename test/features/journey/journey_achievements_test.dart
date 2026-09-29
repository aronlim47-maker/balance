import 'package:balance/data/repositories/achievement_repository.dart';
import 'package:balance/data/repositories/local_achievement_repository.dart';
import 'package:balance/domain/models/achievement_models.dart';
import 'package:balance/features/journey/journey_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local preview shows seven locked achievements', () async {
    final viewModel = JourneyViewModel(LocalAchievementRepository());
    await viewModel.load();
    expect(viewModel.definitions, hasLength(7));
    expect(viewModel.unlockedCount, 0);
    expect(viewModel.awardFor('team_coordination'), isNull);
  });

  test('only a returned award unlocks a card', () async {
    final viewModel = JourneyViewModel(_FakeAchievementRepository());
    await viewModel.load();
    expect(viewModel.definitions, hasLength(7));
    expect(viewModel.unlockedCount, 1);
    expect(viewModel.awardFor('protected_rest'), isNotNull);
    expect(viewModel.awardFor('team_coordination'), isNull);
  });

  test(
    'failed refresh clears awards instead of showing stale unlocks',
    () async {
      final repository = _FakeAchievementRepository();
      final viewModel = JourneyViewModel(repository);
      await viewModel.load();
      repository.fail = true;
      await viewModel.load();
      expect(viewModel.definitions, hasLength(7));
      expect(viewModel.unlockedCount, 0);
      expect(viewModel.errorMessage, isNotNull);
    },
  );
}

class _FakeAchievementRepository implements AchievementRepository {
  bool fail = false;

  @override
  Future<AchievementSnapshot> fetchAchievements() async {
    if (fail) throw Exception('Database unavailable');
    return AchievementSnapshot(
      definitions: achievementV1Catalogue,
      awards: [
        AchievementAward(
          key: 'protected_rest',
          awardedAt: DateTime.utc(2026, 9, 27),
        ),
      ],
    );
  }
}
