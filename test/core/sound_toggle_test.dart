import 'package:balance/core/audio/sound_service.dart';
import 'package:balance/core/shared_widgets/sound_toggle_button.dart';
import 'package:balance/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Records the choice without touching the audio plugin.
class _FakeSound extends SoundService {
  @override
  Future<void> setMusic(bool on) async {
    musicOn = on;
    notifyListeners();
  }
}

Future<_FakeSound> _pump(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  final sound = _FakeSound();
  addTearDown(sound.dispose);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: ChangeNotifierProvider<SoundService>.value(
        value: sound,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: Center(child: SoundToggleButton())),
        ),
      ),
    ),
  );
  return sound;
}

void main() {
  testWidgets('background music is on by default', (tester) async {
    final sound = SoundService();
    addTearDown(sound.dispose);
    expect(sound.musicOn, isTrue);
    expect(sound.effectsOn, isTrue);
  });

  testWidgets('one tap turns the music off and on, with a clear label', (
    tester,
  ) async {
    final sound = await _pump(tester);
    expect(find.byTooltip(SoundToggleButton.turnOffLabel), findsOneWidget);
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);

    await tester.tap(find.byType(SoundToggleButton));
    await tester.pumpAndSettle();
    expect(sound.musicOn, isFalse);
    expect(find.byTooltip(SoundToggleButton.turnOnLabel), findsOneWidget);
    expect(find.byIcon(Icons.music_off_rounded), findsOneWidget);

    await tester.tap(find.byType(SoundToggleButton));
    await tester.pumpAndSettle();
    expect(sound.musicOn, isTrue);
  });

  testWidgets('works without animation and meets tap-target guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final sound = await _pump(tester, reduceMotion: true);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.byType(SoundToggleButton));
    await tester.pump();
    expect(sound.musicOn, isFalse);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('shows nothing when no sound service is provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SoundToggleButton())),
    );
    expect(find.byType(IconButton), findsNothing);
  });
}
