import 'package:balance/domain/models/achievement_models.dart';
import 'package:balance/features/journey/achievement_wall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final award = AchievementAward(
    key: 'protected_rest',
    awardedAt: DateTime(2026, 10, 10, 12),
  );

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AchievementWall(
            definitions: achievementV1Catalogue,
            awardFor: (key) => key == award.key ? award : null,
          ),
        ),
      ),
    ),
  );

  testWidgets('shows all seven badges with practical and RPG names', (
    tester,
  ) async {
    await pump(tester);
    for (final d in achievementV1Catalogue) {
      expect(find.text(d.practicalName), findsOneWidget);
      expect(find.text(d.rpgName), findsOneWidget);
    }
    expect(find.text('UNLOCKED 10 OCT'), findsOneWidget);
    expect(find.text('LOCKED'), findsNWidgets(6));
  });

  testWidgets('tapping a locked badge explains how to unlock it', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Team Coordination'));
    await tester.pumpAndSettle();
    expect(find.text('How to unlock'), findsOneWidget);
    expect(
      find.text('Needs shared tasks, which arrive in a later version.'),
      findsOneWidget,
    );
  });

  testWidgets('badges are announced with their status for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Protected Rest, Sanctuary Keeper\. Unlocked'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
