import 'package:balance/core/shared_widgets/one_shot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Object? key, List<double> seen, {bool reduceMotion = false}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: OneShot(
          duration: const Duration(milliseconds: 400),
          replayKey: key,
          builder: (context, t) {
            seen.add(t);
            return Text(t.toStringAsFixed(2));
          },
        ),
      ),
    );

void main() {
  testWidgets('plays once from 0 to 1 and then stays still', (tester) async {
    final seen = <double>[];
    await tester.pumpWidget(_host('a', seen));
    expect(seen.first, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(seen.last, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(seen.last, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion shows the finished frame at once', (
    tester,
  ) async {
    final seen = <double>[];
    await tester.pumpWidget(_host('a', seen, reduceMotion: true));
    expect(seen.last, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('replays when the replay key changes', (tester) async {
    final seen = <double>[];
    await tester.pumpWidget(_host('a', seen));
    await tester.pumpAndSettle();
    expect(seen.last, 1);
    await tester.pumpWidget(_host('b', seen));
    await tester.pump();
    expect(seen.last, lessThan(1));
    await tester.pumpAndSettle();
    expect(seen.last, 1);
  });
}
