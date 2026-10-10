import 'package:balance/core/theme/app_theme.dart';
import 'package:balance/features/onboarding/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        // The real app theme, as the screen is seen in Balance.
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showOnboarding(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('walks through three pages and closes', (tester) async {
    await open(tester);
    expect(find.text('See when your day does not fit'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a safe trade-off'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Protect rest, without pressure'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
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
}
