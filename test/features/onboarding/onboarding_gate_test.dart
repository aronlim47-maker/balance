import 'package:balance/features/onboarding/onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 1, 12);

  test('a first-time device shows the guide', () {
    expect(
      shouldShowGuide(seenByAccount: false, seenOnDevice: false, now: now),
      isTrue,
    );
  });

  test('an account that has seen the guide never sees it again', () {
    expect(
      shouldShowGuide(
        seenByAccount: true,
        seenOnDevice: false,
        confirmedAt: now,
        now: now,
      ),
      isFalse,
    );
  });

  test('a brand-new account still sees it on a device that showed it before', () {
    expect(
      shouldShowGuide(
        seenByAccount: false,
        seenOnDevice: true,
        confirmedAt: now.subtract(const Duration(minutes: 2)),
        now: now,
      ),
      isTrue,
    );
  });

  test('an older account on a device that showed it before does not', () {
    expect(
      shouldShowGuide(
        seenByAccount: false,
        seenOnDevice: true,
        confirmedAt: now.subtract(const Duration(days: 3)),
        now: now,
      ),
      isFalse,
    );
    expect(
      shouldShowGuide(seenByAccount: false, seenOnDevice: true, now: now),
      isFalse,
    );
  });
}
