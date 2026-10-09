import 'package:balance/data/repositories/achievement_repository.dart';
import 'package:balance/data/repositories/local_achievement_repository.dart';
import 'package:balance/domain/models/achievement_models.dart';
import 'package:balance/features/journey/journey_view_model.dart';
import 'package:balance/features/journey/journey_screen.dart';
import 'package:balance/features/auth/auth_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
    'failed refresh retains the last confirmed awards with an error notice',
    () async {
      final repository = _FakeAchievementRepository();
      final viewModel = JourneyViewModel(repository);
      await viewModel.load();
      repository.fail = true;
      await viewModel.load();
      expect(viewModel.definitions, hasLength(7));
      expect(viewModel.unlockedCount, 1);
      expect(viewModel.awardFor('protected_rest'), isNotNull);
      expect(viewModel.errorMessage, isNotNull);
    },
  );

  testWidgets('achievement load failure offers a working retry', (
    tester,
  ) async {
    final repository = _FakeAchievementRepository()..fail = true;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthViewModel()),
          Provider<AchievementRepository>.value(value: repository),
        ],
        child: const MaterialApp(home: JourneyScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Could not load achievements. Pull to retry.'),
      180,
    );
    expect(
      find.text('Could not load achievements. Pull to retry.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Try again'), 180);
    expect(find.text('Try again'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load achievements. Pull to retry.'),
      findsNothing,
    );
    expect(repository.fetchCount, 2);
  });
}

class _FakeAchievementRepository implements AchievementRepository {
  bool fail = false;
  int fetchCount = 0;

  @override
  Future<AchievementSnapshot> fetchAchievements() async {
    fetchCount++;
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
