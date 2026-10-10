import 'package:balance/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Automated half of the accessibility checklist (evidence pack G): every
/// primary page meets Flutter's tap-target, labelling and contrast guidelines,
/// and still lays out without overflow at 200% text size.
const _tabs = ['TODAY', 'QUESTS', 'COUNCIL', 'SANCTUARY', 'JOURNEY'];

Future<void> _open(WidgetTester tester, String tab) async {
  await tester.tap(find.text(tab).last);
  await tester.pumpAndSettle();
}

void main() {
  for (final tab in _tabs) {
    testWidgets('$tab meets tap-target, label and contrast guidelines', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(const BalanceApp());
      await tester.pumpAndSettle();
      await _open(tester, tab);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }

  testWidgets('all primary pages lay out at 200% text size', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(412, 915),
          textScaler: TextScaler.linear(2),
        ),
        child: const BalanceApp(),
      ),
    );
    await tester.pumpAndSettle();
    for (final tab in _tabs) {
      await _open(tester, tab);
      expect(tester.takeException(), isNull, reason: '$tab at 200% text');
    }
  });
}
