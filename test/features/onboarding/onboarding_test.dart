import 'package:balance/core/router/app_router.dart';
import 'package:balance/core/theme/app_theme.dart';
import 'package:balance/features/onboarding/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? result;

  Future<void> open(WidgetTester tester, {bool reduceMotion = false}) async {
    result = null;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MaterialApp(
          // The real app theme, as the screen is seen in Balance.
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async => result = await showOnboarding(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('walks through five steps, back and forward, and closes', (
    tester,
  ) async {
    await open(tester);
    const titles = [
      'Add your free time',
      'Add your tasks',
      'See if your day fits',
      'Fix it safely',
      'Rest and look back',
    ];
    expect(find.text(titles.first), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    for (final title in titles.skip(1)) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Fix it safely'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(result, isNull);
  });

  testWidgets('Show me closes the guide with that page', (tester) async {
    await open(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show me on Quests'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(result, AppRoutes.quests);
  });

  testWidgets('reduced motion shows each animation finished', (tester) async {
    await open(tester, reduceMotion: true);
    // The final frame of step 1 without any animation time passing.
    expect(find.text('3h free'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('5h of work planned'), findsOneWidget);
  });

  testWidgets('can be skipped and meets accessibility guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    semantics.dispose();
  });

  testWidgets('every step lays out at 200% text size', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(412, 915),
          textScaler: TextScaler.linear(2),
        ),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      expect(tester.takeException(), isNull, reason: 'step ${i + 1}');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull, reason: 'step 5');
  });
}
