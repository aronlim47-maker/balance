import 'package:balance/core/theme/app_theme.dart';
import 'package:balance/features/sanctuary/camp_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the camp scene paints at every time of day', (tester) async {
    for (final hour in [3, 6, 12, 18, 22]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: CampScene(now: DateTime(2026, 10, 13, hour))),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'hour $hour');
      expect(find.bySemanticsLabel(RegExp('Rest camp')), findsOneWidget);
    }
  });

  testWidgets('breathing guides in, hold and out, then offers Again', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showBreathing(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Breathe in'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Hold'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Breathe out'), findsOneWidget);

    // Five breaths of 12 seconds make one minute.
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('Well done'), findsOneWidget);
    expect(find.text('Again'), findsOneWidget);

    await tester.tap(find.text('Back to camp'));
    await tester.pumpAndSettle();
    expect(find.byType(BreathingScreen), findsNothing);
  });

  testWidgets('Stop leaves at any time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const BreathingScreen()),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Breathe in'), findsOneWidget);
    expect(
      find.text('Optional and private. Nothing is recorded or scored.'),
      findsOneWidget,
    );
  });
}
